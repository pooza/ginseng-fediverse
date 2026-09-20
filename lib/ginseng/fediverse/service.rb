module Ginseng
  module Fediverse
    class Service
      include Package

      attr_reader :token, :http
      attr_accessor :mulukhiya_enable

      def initialize(uri = nil, token = nil)
        @config = config_class.instance
        @token = token || default_token
        @mulukhiya_enable = false
        @http = http_class.new
        # 🔴🔴 **ガードは継承ではなく prepend で差し込む (#280 / #282)。**
        # ⚠⚠ 利用側は全員 `http_class` を自前の HTTP へ差し替えているので、
        # `Ginseng::HTTP` のサブクラスとして足すと**継承経路に現れない** — この
        # gem が出す要求だけに、**`http_class` が何を返しても**効かせる。
        @http.singleton_class.prepend(RedirectGuard)
        @http.base_uri = uri ? URI.parse(uri) : default_uri
      end

      def uri
        return http.base_uri
      end

      def token=(token)
        @token = token
        @account = nil
      end

      def mulukhiya_enable?
        return @mulukhiya_enable || false
      end

      alias mulukhiya? mulukhiya_enable?

      def retry_limit
        return http.retry_limit
      end

      def retry_limit=(cnt)
        http.retry_limit = cnt
      end

      def nodeinfo
        headers = {'X-Mulukhiya' => Package.full_name}
        r = http.get('/.well-known/nodeinfo', {headers:}).parsed_response
        return http.get(r['links'].first['href'], {headers:}).parsed_response
      rescue
        return {}
      end

      alias info nodeinfo

      def node_name
        return nodeinfo.dig('metadata', 'nodeName')
      end

      def maintainer_name
        return nodeinfo.dig('metadata', 'maintainer', 'name')
      end

      def maintainer_email
        return nodeinfo.dig('metadata', 'maintainer', 'email')
      end

      def max_post_text_length
        return nil
      end

      def max_media_attachments
        return nil
      end

      def characters_reserved_per_url
        return nil
      end

      def upload(path, params = {})
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def upload_remote_resource(uri, params = {})
        path = File.join(environment_class.dir, 'tmp/media', uri.to_s.sha256)
        File.write(path, http.get(uri))
        return upload(path, params)
      ensure
        FileUtils.rm_f(path)
      end

      def fetch_featured_tags(id, params = {})
        return nil
      end

      def fetch_followed_tags(params = {})
        return nil
      end

      def filters(params = {})
        return nil
      end

      def announcements(params = {})
        return nil
      end

      def create_uri(href)
        return http.create_uri(href)
      end

      def create_streaming_uri(stream = 'user')
        raise ImplementError, "'#{__method__}' not implemented"
      end

      alias streaming_uri create_streaming_uri

      # ⚠⚠ **渡された hash を書き換えないこと (#258)。** 複製せずに書き込むと、
      # 呼び側の hash に `X-Mulukhiya` や（`MastodonService` では）**設定の
      # トークン**が残り、**同じ hash を使い回す次の要求（別ホスト宛でも）へ
      # 持ち越される**。⚠ 呼び出しは 3 サービス 38 箇所あり、そのすべてが
      # `create_headers(params[:headers])` の形なので、**複製はここに 1 つ置く**。
      # ⚠ `ginseng-core` も同じ型を `HTTP#request` 側の複製で潰している。
      def create_headers(headers = {})
        headers = (headers || {}).dup
        headers['X-Mulukhiya'] ||= package_class.full_name unless mulukhiya_enable?
        return headers
      end

      def default_token
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def default_uri
        raise ImplementError, "'#{__method__}' not implemented"
      end

      # 🔴🔴 **入口で ASCII-8BIT のラベルだけ剥がす (#276)。**
      #
      # ⚠⚠ **「本番の口は無事」は成り立っていなかった。** `#276` は `escape_sigils` を
      # 直接呼ぶ経路だけが落ちると書いていたが、**こちらは例外にならずに黙って化ける**。
      # 🔴 実測（`v3.0.0`）: `"ほげ #tag @pooza".b` → `"������ # tag @ pooza"`。
      # ⚠ `sanitize!` が中で Nokogiri に渡すので、**ASCII-8BIT のラベルが付いた
      # 妥当な UTF-8 が、1 文字ずつ置換文字に潰される**。
      # ⚠⚠ **Sequel / SQLite は非 ASCII をこの形で返す**ので、利用側は素直に踏む
      # （`pooza/makoto2#171` / `#280`）。
      #
      # 🔴🔴 **ここでは `to_utf8` を使わない（弾かない）。** ⚠⚠ **本番の投稿の口**なので、
      # 妥当でないバイト列で例外を上げると **その枠が 1 通も投稿されなくなる** —
      # `#277` が困っていることそのものを、こちらが作ることになる。
      # ⚠ **ラベルを剥がすだけなら中身は 1 バイトも動かない**ので、
      # 🔴 **いま通っているものは全部そのまま通る**（追加だけの変更）。
      # ⚠ 妥当でないバイト列は従来どおり `sanitize!` の先で潰れる（挙動を変えない）。
      def self.sanitize_status(text)
        text = Text.relabel_binary(text.to_s).dup
        text.delete!("\n") if text.match?(/<br.*?>/)
        text.gsub!(/[[:blank:]]*<br.*?>/, "\n")
        text.gsub!(%r{[[:blank:]]*</p.*?>}, "\n\n")
        text.gsub!(/<p.*?>/, '')
        text.sanitize!
        return escape_sigils(text).strip
      end

      # 🔴 **本文を投稿先に再解釈させないための区切りを入れる**（#273）。
      #
      # ⚠⚠ **当てるのは「実際にリンク化する `#` / `@`」だけ。** 以前は
      # `gsub!(/[@#]/, '\\0 ')` で無条件に全部置換していたが、⚠ **無毒化の必要が
      # 無い場所まで目に見えて壊していた** — 実データ（`pooza/makoto2` の楽曲
      # コーパス 4,305 行）では `@` を含む曲名 12 行がすべて `H@ppy Together!!!`
      # 系で、**投稿先のメンションに 1 件も当たらないのに `H@ ppy` に変わっていた**。
      #
      # ⚠⚠ **判定はこの gem の正本（`Parser` のパターン ＝ config/lib.yaml）を使う。**
      # 🔴 **投稿先 1 実装の正規表現を写さない** — 写すと向こうが動いた日に黙ってずれる。
      #
      # ⚠ **区切りは半角スペースのまま。ZWSP へは寄せない**（#273 で判断）。
      # 効き目は同等だが、🔴 **ZWSP は「壊れているのに壊れて見えない」状態を作り**、
      # コピペ・検索・他実装へ見えない文字が付いて回る。⚠ **スペースなら、次に読む
      # 人が「なぜここに空白が」と辿れる。**
      #
      # ⚠⚠ **当てるのは `Parser.hashtag_sigil_pattern`**（#275）。抽出とタグ名は共有し、
      # 🔴 **境界だけ広く取る** — 無毒化は「広く」、抽出は「正確」で向きが逆なため。
      # ⚠ **数字だけのタグ**（`#123`）を拾わないのは正しい — 🔴 Mastodon は `[[:alpha:]]` を
      # 1 文字要求し、mfm-js は数字のみを弾くので、**どちらもタグにしない**。
      # 🔴🔴 **「拾えないのはそれだけ」ではない（リリース前レビュー）。** ⚠⚠ mfm-js の
      # 名前の文字集合は Mastodon よりはるかに広く（除くのは空白と記号の一部だけ）、
      # **`#-tag` `#☆` `#😀` は Misskey がタグにするのに、ここでは素通りする**。
      # ⚠ タグ名を抽出と共有している以上こうなる（抽出を広げると本文を壊す）ので、
      # **限界として引き受けている**。
      #
      # ⚠⚠ **置換は元の印をそのまま残す（半角 `#` を決め打ちにしない）** —
      # 🔴 全角 `＃` を半角へ寄せると、**無毒化のついでに本文を書き換える**ことになる。
      def self.escape_sigils(text)
        # ⚠⚠ **当てるパターンが UTF-8 なので、先に寄せる (#276)。** 🔴 `hashtag_pattern`
        # は `·`（U+00B7）を含むため、**ASCII-8BIT の文字列に当てると
        # `Encoding::CompatibilityError`** になる。⚠ `v2.0.0` でこれを公開したので、
        # **直接呼ぶ経路が新しく狭かった**。
        # ⚠ `sanitize_status` 経由では既に寄っているので、そちらでは何も起きない。
        text = Text.to_utf8(text, "#{name}.#{__callee__}")
        text = text.gsub(Parser.hashtag_sigil_pattern) do
          matched = Regexp.last_match
          "#{matched[0].delete_suffix(matched[1])} #{matched[1]}"
        end
        return text.gsub(Parser.acct_pattern) {Regexp.last_match(1).sub('@', '@ ')}
      end

      def self.create_tag(word)
        return "##{create_tag_base(word)}"
      end

      def self.create_tag_base(word)
        return word.strip.gsub(/[^[:alnum:]]+/, '_').gsub(/(^[_#]+|_$)/, '')
      end

      private

      def oauth_client_path
        return File.join(environment_class.dir, 'tmp/cache/oauth_cilent.json')
      end

      def clear_oauth_client
        FileUtils.rm_f(oauth_client_path)
      end
    end
  end
end
