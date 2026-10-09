module Ginseng
  module Fediverse
    class NoteURI < Ginseng::URI
      include Package

      def initialize(options = {})
        super
        @config = Config.instance
        @logger = logger_class.new
      end

      def note_id
        @config['/parser/note/url/patterns'].each do |pattern|
          next unless matches = path.match(pattern)
          return matches[1]
        end
        return nil
      end

      alias id note_id

      def valid?
        return absolute? && id.present?
      end

      def publicize!
        self.path = "/notes/#{id}" if id
        return self
      end

      def publicize
        return clone.publicize!
      end

      def visibility
        return note['visibility']
      end

      # 連合なし（`localOnly`）か。⚠ チャンネルのノートもここに入る。
      def local_only?
        return note['localOnly'] ? true : false
      end

      # 外へ出してよい公開範囲か。
      #
      # 🔴🔴 **`visibility` だけで決めない (#302)。** Misskey の連合なしのノートは
      # `visibility` が `public` のままで、`localOnly` が別に立つ。⚠⚠ 利用側は
      # この判定で**本文を外部へ転載するか**を決めている（`ginseng-piefed` の
      # `clip`、`mulukhiya-toot-proxy` のクリップ）ので、`visibility` だけを見ると
      # **作者が連合させないと決めた本文が外へ出る**。
      def public?
        return visibility == 'public' && !local_only?
      end

      def parser
        unless @parser
          @parser = NoteParser.new(note['text'])
          @parser.service = service
        end
        return @parser
      end

      def subject
        unless @subject
          @subject = note['cw'] if note['cw'].present?
          @subject ||= note['text']
          @subject.sanitize!
          URI.scan(@subject.dup) {|uri| @subject.gsub!(uri.to_s, '')}
          @subject.gsub!(/[\s[:blank:]]+/, ' ')
        end
        return @subject
      end

      # ノートを取りにいく先のホストを検証する callable (#306)。⚠ **利用側の上書き点。**
      #
      # 🔴🔴 **この URL のホストへ、こちらから要求を撃つ。** URL が外部由来になる利用側
      # （渡された URL をクリップする口）では、検証が無いと**初段ホストへの SSRF** になる
      # — `http://127.0.0.1:<port>/…` を渡せば、ローカルのサーバーへ届いていた（実測）。
      # ⚠ 既定は `Ginseng::PublicHost.validator`。**公開アドレスだけに解決される名前**を通す。
      #
      # ⚠⚠ **落ちるものは「内部」だけではない。** どれも `GatewayError: Rejected host '…'` で、
      # 要求は 1 本も出ない。
      # - IP アドレスのリテラル、ドットを含まない名前、最後のラベルが数字で始まる名前
      # - 内部アドレスに解決される名前（公開と内部が混ざって返る名前を含む）
      # - 🔴 **解決できない名前と、名前解決の一時的な失敗**（締め切り 3 秒）。⚠ 検証は
      #   再送の外なので、**ここは再送されない**（5.0.0 より前は接続の失敗として再送していた）
      # ⚠ 拒否は**ログを残さない**。残したい利用側は、上書きした validator の中で残す。
      #
      # ⚠⚠ **通した相手へは、名前解決の答え（IP アドレス）へ接続を固定する。** 名前で検証して
      # 名前で接続すると、DNS リバインディングで抜けられるため。
      # - 🔴 `/etc/hosts` は見ない（DNS だけを引く）。hosts で向き先を変えている名前も、
      #   DNS の答えへ繋ぐ
      # - 🔴 プロキシ越し（`http_proxy` などの環境変数）では固定できないので、
      #   `Ginseng::PinningError`（`GatewayError` の子）で落とす
      #
      # ⚠⚠ **自サーバーが内部アドレスに解決される構成では、自サーバー宛だけ外す。**
      # 「自サーバー」が何かは gem からは決められないので、利用側が上書きする。
      #
      #   def host_validator
      #     return nil if own_origin?
      #     return super
      #   end
      #
      #   # ⚠ 設定で決まる値と、scheme・ホスト・ポートの 3 つとも比べる。
      #   def own_origin?
      #     return scheme == 'https' && inferred_port == 443 &&
      #         normalized_host == Environment.domain_name
      #   end
      #
      # ⚠ nil を返すと検証しない（5.0.0 より前と同じ）。
      # 🔴🔴 **ホスト名だけを比べて外さない。** `http://<自サーバー>:6379/…` のような URL で、
      # **自サーバーの任意のポートへ要求が出る** — 外すのが要る構成は、ちょうど内部のポートに
      # 届く構成でもある。⚠ `host` は書かれたままの字面なので、比べるのは `normalized_host`。
      # 🔴 **外す条件を URL の中身から作らないこと** — 比べる相手は設定で決まる値にする。
      #
      # ⚠⚠ **検証を挿す場所は `service` ではなく `note`。** 利用側は `service` を丸ごと
      # 上書きしている（自前のサービスクラスを返す）ので、そこへ置くと届かない。
      # 🔴 **裏返すと、`service` を直に使う口は検証を通らない**（`uri.service.nodeinfo` など）。
      # 外部由来の URL から作った `service` で、`note` を通さずに要求を出さないこと。
      # ⚠ `TootURI#host_validator` も同じ形（説明はここが正本）。
      def host_validator
        return Ginseng::PublicHost.validator
      end

      def service
        unless @service
          uri = clone
          uri.path = '/'
          uri.query = nil
          uri.fragment = nil
          @service = MisskeyService.new(uri)
          @service.token = nil
        end
        return @service
      end

      def note
        unless @note
          @note = service.fetch_status(id, {host_validator:}.compact)
          raise NotFoundError, "Note '#{self}' not found" unless @note
          if error = note['error']
            raise GatewayError, "Note '#{self}' is invalid (#{error['message']})"
          end
        end
        return @note
      end

      alias status note
    end
  end
end
