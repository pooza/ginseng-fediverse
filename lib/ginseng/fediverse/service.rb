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

      def self.sanitize_status(text)
        text = text.dup
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
      # 🔴 **拾えないものが 2 つある**（⚠ **以前の無条件置換でも拾えていない**）。
      # 全角の `＃` と、数字だけのタグ（`#123`）。⚠⚠ **無毒化は「広く取る」ほうが
      # 安全で、抽出は「正確」なほうが安全** — 向きが逆なので、同じパターンを共有
      # している限りこの穴は残る。
      def self.escape_sigils(text)
        text = text.gsub(Parser.hashtag_pattern) do
          matched = Regexp.last_match
          "#{matched[0].delete_suffix("##{matched[1]}")}# #{matched[1]}"
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
