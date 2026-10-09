module Ginseng
  module Fediverse
    class TootURI < Ginseng::URI
      include Package

      def initialize(options = {})
        super
        @config = Config.instance
        @logger = logger_class.new
      end

      def toot_id
        @config['/parser/toot/url/patterns'].each do |pattern|
          next unless matches = path.match(pattern)
          id = matches[1]
          return id.to_i if id.match?(/^[[:digit:]]+$/)
          return id
        end
        return nil
      end

      alias id toot_id

      # ⚠⚠ **どのパターンに一致したかで種別を決める (#251)。** 値の見た目
      # （数字だけかどうか）で判定してはいけない — **数字だけの username は
      # Mastodon で有効**（`/users/123/statuses/456`）なので、見た目で振ると
      # numeric_ap_id と区別がつかず、`publicize` が黙って no-op になる。
      ACCOUNT_ID_PATTERNS = {
        username: %r{^/users/([[:word:]]+)/statuses/[[:digit:]]+}i,
        numeric_ap_id: %r{^/ap/users/([[:digit:]]+)/statuses/[[:digit:]]+}i,
      }.freeze

      # path に現れるアカウント識別子。`/users/<username>/` では username を、
      # numeric_ap_id 形式 `/ap/users/<id>/` では数値 ID を返す (#243)。
      def account_id
        return account_id_entry&.last
      end

      # 公開 URL `/@<username>/<id>` を組み立てられる場合の username。
      # numeric_ap_id 形式では数値 ID しか分からず、`/@` は username を前提と
      # するため nil を返す。
      def account_username
        entry = account_id_entry
        return nil unless entry&.first == :username
        return entry.last
      end

      def valid?
        return absolute? && id.present?
      end

      # 公開 Web URL 形式へ書き換える。
      #
      # ⚠ numeric_ap_id 形式 `/ap/users/<id>/statuses/<id>` は no-op。数値 ID から
      # username を解くには API 往復が要り、publicize はフィード生成の per-link
      # 経路から呼ばれるためここではネットワークを踏まない。誤った `/@<数値 ID>/`
      # を作るくらいなら AP 形式のまま返す (#243)。
      def publicize!
        self.path = "/@#{account_username}/#{toot_id}" if account_username && toot_id
        return self
      end

      def publicize
        return clone.publicize!
      end

      def visibility
        return toot['visibility']
      end

      # 連合なし（`local_only`）か。⚠ 本家 Mastodon には無く、glitch-soc / Hometown が
      # 返す。無ければ false。
      def local_only?
        return toot['local_only'] ? true : false
      end

      # 外へ出してよい公開範囲か。
      #
      # 🔴 **`visibility` だけで決めない (#302)。** 連合なしのトゥートも `visibility` は
      # `public` のまま。⚠ 理由は `NoteURI#public?` と同じ。
      def public?
        return visibility == 'public' && !local_only?
      end

      def subject
        unless @subject
          @subject = toot['spoiler_text'] if toot['spoiler_text'].present?
          @subject ||= toot['content']
          @subject.sanitize!
          URI.scan(@subject.dup) {|uri| @subject.gsub!(uri.to_s, '')}
          @subject.gsub!(/[\s[:blank:]]+/, ' ')
        end
        return @subject
      end

      # トゥートを取りにいく先のホストを検証する callable (#306)。⚠ **利用側の上書き点。**
      #
      # 🔴🔴 **この URL のホストへ、こちらから要求を撃つ。** 検証が無いと、URL が外部由来に
      # なる利用側では初段ホストへの SSRF になる。
      # ⚠ 何が落ちるか・自サーバー宛の外し方・`service` を直に使う口には効かないことは、
      # `NoteURI#host_validator` と同じ（説明はあちらが正本）。
      # ⚠⚠ **検証を挿す場所は `service` ではなく `toot`。** 利用側は `service` を丸ごと
      # 上書きしているので、そこへ置くと届かない。
      def host_validator
        return Ginseng::PublicHost.validator
      end

      def service
        unless @service
          uri = clone
          uri.path = '/'
          uri.query = nil
          uri.fragment = nil
          @service = MastodonService.new(uri)
          @service.token = nil
        end
        return @service
      end

      def toot
        unless @toot
          @toot = service.fetch_status(id, {host_validator:}.compact)
          raise NotFoundError, "Toot '#{self}' not found" unless @toot
          raise GatewayError, "Toot '#{self}' is invalid (#{toot['error']})" if @toot['error']
        end
        return @toot
      end

      alias status toot

      private

      # ⚠ 一致したパターンの**種別と捕獲した値を対で**返す。種別を捨てると、
      # 受け取った側が値の見た目で判定し直すことになり #251 が再発する。
      def account_id_entry
        ACCOUNT_ID_PATTERNS.each do |kind, pattern|
          next unless matches = pattern.match(path)
          return [kind, matches[1]]
        end
        return nil
      end
    end
  end
end
