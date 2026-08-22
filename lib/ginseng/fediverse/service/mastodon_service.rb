module Ginseng
  module Fediverse
    class MastodonService < Service
      include Package

      def nodeinfo
        unless @nodeinfo
          @nodeinfo = http.get('/api/v1/instance').parsed_response.merge(super)
          @nodeinfo['metadata'] = {
            'nodeName' => @nodeinfo['title'],
            'maintainer' => maintainer,
          }
        end
        return @nodeinfo
      end

      # 管理画面で連絡先アカウントが未設定のインスタンスでは contact_account が
      # nil になる。以前はここで NoMethodError になり nodeinfo 全体が取れなかった
      # (#238)。email だけは instance API から取れるので、名前のみ落として返す。
      def maintainer
        contact = @nodeinfo['contact_account']
        return {
          'name' => contact && (contact['display_name'].presence || contact['username']),
          'email' => @nodeinfo['email'],
        }
      end

      alias info nodeinfo

      def create_parser(text = '')
        parser = TootParser.new(text)
        parser.max_length = max_post_text_length
        return parser
      end

      def search_status_id(status)
        if status.is_a?(URI) && (status.host == uri.host)
          uri = TootURI.parse(status)
          status = status.id if uri.valid?
        end
        return status
      end

      def search_attachment_id(attachment)
        return attachment
      end

      def fetch_status(id, params = {})
        response = http.get("/api/v1/statuses/#{search_status_id(id)}", {
          headers: create_headers(params[:headers]),
        })
        raise GatewayError, response['error'] if response['error']
        return response
      end

      alias fetch_toot fetch_status

      def fetch_status_source(id, params = {})
        response = http.get("/api/v1/statuses/#{search_status_id(id)}/source", {
          headers: create_headers(params[:headers]),
        })
        raise GatewayError, response['error'] if response['error']
        return response
      end

      def post(body, params = {})
        body = {status: body.to_s} unless body.is_a?(Hash)
        body = body.deep_symbolize_keys
        body[:in_reply_to_id] = params.dig(:reply, :id) if params[:reply]
        return http.post('/api/v1/statuses', {
          body: body.compact,
          headers: create_headers(params[:headers]),
        })
      end

      alias toot post

      def delete_status(id, params = {})
        return http.delete("/api/v1/statuses/#{search_status_id(id)}", {
          headers: create_headers(params[:headers]),
        })
      end

      alias delete_toot delete_status

      # ⚠ **上流の GatewayError を握り潰さない** (#246)。かつてここには
      # `rescue GatewayError => e; raise ValidateError, "UploadError (...)"` が
      # あったが、`ValidateError` は `RequestError` の子で `GatewayError` の子で
      # はないため、詰め替えた時点で `response` / `source_status` /
      # `source_body` がすべて失われ、呼び側は `"UploadError (Bad response
      # 401)"` という**文字列**しか受け取れなくなっていた。
      #
      # そのせいで mulukhiya 側では、`rescue Ginseng::GatewayError` に掛からず
      # 401 のアラート抑止も 413 の「上限サイズ超過」文言も一切到達せず、
      # ボットの無効トークン連打がそのまま管理者へのアラートメールになった。
      # クライアントに返るステータスも上流の 401/413 ではなく 422 だった。
      #
      # アップロード失敗であることは呼び側では経路で分かっているので、例外
      # クラスで区別する必要はない。MisskeyService / PleromaService の
      # `#upload` と同じく、上流が返した理由をそのまま素通しする。
      def upload(path, params = {})
        params[:response] ||= :raw
        params[:version] ||= 1
        body = {}
        body[:description] = params[:description] if params[:description]
        response = http.upload("/api/v#{params[:version]}/media", path, {
          body:,
          headers: create_headers(params[:headers]),
        })
        return response if params[:response] == :raw
        return JSON.parse(response.body)['id'].to_i
      end

      def update_media(id, payload, params = {})
        case payload.dig(:thumbnail, :tempfile)
        in File | Tempfile
          payload[:thumbnail] = File.new(payload[:thumbnail][:tempfile].path, 'rb')
        in String
          payload[:thumbnail] = File.new(payload[:thumbnail][:tempfile], 'rb')
        in NilClass
          payload.delete(:thumbnail)
        end
        if payload[:thumbnail]
          return http.upload(create_uri("/api/v1/media/#{search_attachment_id(id)}"), nil, {
            method: :put,
            payload:,
            headers: create_headers(params[:headers]),
          })
        else
          return http.put(create_uri("/api/v1/media/#{search_attachment_id(id)}"), {
            body: payload,
            headers: create_headers(params[:headers]),
          })
        end
      end

      alias update_attachment update_media

      def favourite(id, params = {})
        return http.post("/api/v1/statuses/#{search_status_id(id)}/favourite", {
          headers: create_headers(params[:headers]),
        })
      end

      alias fav favourite

      def reblog(id, params = {})
        return http.post("/api/v1/statuses/#{search_status_id(id)}/reblog", {
          headers: create_headers(params[:headers]),
        })
      end

      alias boost reblog

      def bookmark(id, params = {})
        return http.post("/api/v1/statuses/#{search_status_id(id)}/bookmark", {
          headers: create_headers(params[:headers]),
        })
      end

      # ⚠ **media_attributes を含む body は JSON で送る。**form-urlencoded に
      # 畳むと Hash の配列を表現できない (pooza/mulukhiya-toot-proxy#4621)。
      #
      # `media_attributes[0][id]=...` という数字の添字は、Rack / Rails 側で
      # **`fields_for` 形式の Hash `{"0" => {...}}`** に解釈され、配列にならない。
      # Mastodon の `UpdateStatusService#update_media_attachments!` は
      # `(@options[:media_attributes] || []).each do |attributes|` と回すので、
      # Hash を each した `["0", {...}]`（Array）が渡り、`attributes[:id]` で
      # **`TypeError: no implicit conversion of Symbol into Integer` ＝ 500** になる。
      #
      # ⚠ **空添字 `media_attributes[][id]` でも配列にはなるが、採らない。**
      # 「同じキーが再出現したら次の要素」という Rack の暗黙のグルーピングに
      # 依存し、要素ごとのキーの並びで壊れうる。JSON なら配列は配列のまま届く。
      #
      # ⚠ **Content-Type は「立てる」ではなく「上書きする」ために書いている。**
      # ginseng-core の `create_headers` は `Content-Type ||= 'application/json'`
      # なので、**無指定なら放っておいても JSON になる**。潰しているのは
      # **呼び出し側が非 JSON の Content-Type を渡してくる場合**で、`||=` では
      # それが残り、`create_body` が `to_json` せず HTTParty が Hash を
      # form-urlencode する（`HashConversions.to_params` でまた数字の添字）。
      # ⚠ mulukhiya は受信ヘッダをそのまま `params[:headers]` に乗せて渡すので、
      # これは実際に起こりうる経路。⚠⚠ **`||=` に「直す」と 500 に戻る。**
      # ⚠ **`create_headers` を必ず通す。**このメソッドだけ素の
      # `params[:headers]` を使っており、**`X-Mulukhiya` が付かなかった**
      # (pooza/mulukhiya-toot-proxy#4621)。
      #
      # モロヘイヤは上流 Mastodon の前に立つプロキシで、nginx は
      # `X-Mulukhiya` の有無で「モロヘイヤへ通す／素通しする」を振り分ける。
      # 名乗らずに出ると **モロヘイヤ自身の PUT がモロヘイヤへ送り返される**。
      # ステージング実機（dev24）では、`X-Mulukhiya-Purpose` を引き継いだ場合は
      # ループ、引き継がない場合は map の reject で **405** になった。
      # `fetch_status` / `fetch_status_source` / `bookmark` 等は通しており、
      # ここだけが例外だった。
      #
      # ⚠ `create_headers` の `Authorization` は `||=` なので、呼び側が渡した
      # 利用者のトークンは上書きされない（渡されなければ設定のトークンが入る）。
      def update_status(id, body, params = {})
        body = {status: body.to_s} unless body.is_a?(Hash)
        body.deep_symbolize_keys!
        body = body.compact
        headers = create_headers(params[:headers])
        headers['Content-Type'] = 'application/json' if body[:media_attributes]
        return http.put("/api/v1/statuses/#{id}", {body:, headers:})
      end

      def search(keyword, params = {})
        params[:version] ||= 2
        params[:q] = keyword
        uri = create_uri("/api/v#{params[:version]}/search")
        uri.query_values = params
        return http.get(uri, {headers: create_headers(params[:headers])})
      end

      def follow(id, params = {})
        return http.post("/api/v1/accounts/#{id}/follow", {
          headers: create_headers(params[:headers]),
        })
      end

      def unfollow(id, params = {})
        return http.post("/api/v1/accounts/#{id}/unfollow", {
          headers: create_headers(params[:headers]),
        })
      end

      def statuses(params = {})
        response = http.get('/api/v1/timelines/home', {headers: create_headers(params[:headers])})
        return response.parsed_response
      end

      alias toots statuses

      def announcements(params = {})
        response = http.get('/api/v1/announcements', {headers: create_headers(params[:headers])})
        return response.parsed_response.map do |entry|
          entry.deep_symbolize_keys.merge(
            text: entry['content'].sanitize.strip,
          ).except(
            :read,
          )
        end
      end

      def followers(params = {})
        id = params[:id] || @config['/mastodon/account/id']
        uri = create_uri("/api/v1/accounts/#{id}/followers")
        uri.query_values = {limit: @config['/mastodon/followers/limit']}
        return http.get(uri, {headers: create_headers(params[:headers])})
      end

      def followees(params = {})
        id = params[:id] || @config['/mastodon/account/id']
        uri = create_uri("/api/v1/accounts/#{id}/following")
        uri.query_values = {limit: @config['/mastodon/followees/limit']}
        return http.get(uri, {headers: create_headers(params[:headers])})
      end

      alias following followees

      def fetch_featured_tags(id, params = {})
        return http.get("/api/v1/accounts/#{id}/featured_tags", {
          headers: create_headers(params[:headers]),
        })
      end

      def fetch_followed_tags(params = {})
        return http.get('/api/v1/followed_tags', {
          headers: create_headers(params[:headers]),
        })
      end

      def filters(params = {})
        params.deep_symbolize_keys!
        response = http.get('/api/v2/filters', {headers: create_headers(params[:headers])})
        case params
        in {phrase: phrase}
          return response.parsed_response.select do |filter|
            filter['keywords'].any? {|v| v['keyword'] == phrase}
          end
        in {tag: tag}
          return response.parsed_response.select do |filter|
            filter['keywords'].any? {|v| v['keyword'] == tag.to_hashtag}
          end
        else
          return response
        end
      end

      def register_filter(params)
        return http.post('/api/v2/filters', {
          body: {
            title: params[:title] || params[:phrase],
            context: params[:context] || [:home, :public],
            keywords_attributes: [{keyword: params[:phrase], whole_word: false}],
          },
          headers: create_headers(params[:headers]),
        })
      end

      def unregister_filter(id, params = {})
        return http.delete("/api/v2/filters/#{id}", {
          headers: create_headers(params[:headers]),
        })
      end

      def oauth_client(type = :default)
        unless File.exist?(oauth_client_path)
          response = http.post('/api/v1/apps', {
            body: {
              client_name: package_class.name,
              website: @config['/package/url'],
              redirect_uris: @config['/mastodon/oauth/redirect_uri'],
              scopes: @config['/mastodon/oauth/scopes'].join(' '),
            },
          })
          File.write(oauth_client_path, response.body)
        end
        return JSON.parse(File.read(oauth_client_path))
      end

      def oauth_uri(type = :default)
        return nil unless oauth_client(type)
        uri = create_uri('/oauth/authorize')
        uri.query_values = {
          client_id: oauth_client(type)['client_id'],
          response_type: 'code',
          redirect_uri: @config['/mastodon/oauth/redirect_uri'],
          scope: @config['/mastodon/oauth/scopes'].join(' '),
        }
        return uri
      end

      def auth(code, type = :default)
        return http.post('/oauth/token', {
          headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
          body: {
            'grant_type' => 'authorization_code',
            'redirect_uri' => @config['/mastodon/oauth/redirect_uri'],
            'client_id' => oauth_client(type)['client_id'],
            'client_secret' => oauth_client(type)['client_secret'],
            'code' => code,
          },
        })
      end

      def create_tag_uri(tag)
        return create_uri("/tags/#{tag.to_hashtag_base}")
      end

      alias tag_uri create_tag_uri

      def create_streaming_uri(stream = 'user')
        uri = URI.parse(info.dig('urls', 'streaming_api'))
        uri.path = '/api/v1/streaming'
        uri.query_values = {'access_token' => token, 'stream' => stream}
        return uri
      end

      alias streaming_uri create_streaming_uri

      def max_post_text_length
        length = info.dig('configuration', 'statuses', 'max_characters')
        length ||= config['/mastodon/status/default_max_length']
        return length
      rescue
        return config['/mastodon/status/default_max_length']
      end

      def max_media_attachments
        return info.dig('configuration', 'statuses', 'max_media_attachments') || 4
      end

      def characters_reserved_per_url
        return info.dig('configuration', 'statuses', 'characters_reserved_per_url')
      end

      def default_token
        return @config['/mastodon/token']
      end

      def create_headers(headers = {})
        headers ||= {}
        headers['Authorization'] ||= "Bearer #{token}"
        return super
      end

      def default_uri
        return URI.parse(@config['/mastodon/url'])
      end
    end
  end
end
