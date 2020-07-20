require 'rest-client'

module Ginseng
  module Fediverse
    class MastodonService < Service
      include Package

      def fetch_status(id)
        response = http.get("/api/v1/statuses/#{id}")
        raise Ginseng::GatewayError, response['error'] if response['error']
        return response
      end

      alias fetch_toot fetch_status

      def post(body, params = {})
        body = {status: body.to_s} unless body.is_a?(Hash)
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return http.post('/api/v1/statuses', {body: body.to_json, headers: headers})
      end

      alias toot post

      def upload(path, params = {})
        params[:version] ||= 1
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        response = http.upload("/api/v#{params[:version]}/media", path, headers)
        return response if params[:response] == :raw
        return JSON.parse(response.body)['id'].to_i
      end

      def update_media(id, body, params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        if body.dig(:thumbnail, :tempfile).is_a?(File)
          body[:thumbnail] = File.new(body[:thumbnail][:tempfile].path, 'rb')
        end
        return RestClient::Request.new(
          url: create_uri("/api/v1/media/#{id}").to_s,
          method: :put,
          headers: headers,
          payload: body,
        ).execute
      end

      def favourite(id, params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return http.post("/api/v1/statuses/#{id}/favourite", {
          body: '{}',
          headers: headers,
        })
      end

      alias fav favourite

      def reblog(id, params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return http.post("/api/v1/statuses/#{id}/reblog", {
          body: '{}',
          headers: headers,
        })
      end

      alias boost reblog

      def bookmark(id, params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return http.post("/api/v1/statuses/#{id}/bookmark", {
          body: '{}',
          headers: headers,
        })
      end

      def search(keyword, params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        params[:version] ||= 2
        params[:q] = keyword
        uri = create_uri("/api/v#{params[:version]}/search")
        uri.query_values = params
        return http.get(uri, {headers: headers})
      end

      def follow(id, params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return http.post("/api/v1/accounts/#{id}/follow", {
          body: '{}',
          headers: headers,
        })
      end

      def unfollow(id, params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return http.post("/api/v1/accounts/#{id}/unfollow", {
          body: '{}',
          headers: headers,
        })
      end

      def statuses(params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        r = http.get('/api/v1/timelines/home', {headers: headers})
        raise Ginseng::GatewayError, "Bad response #{r.code}" unless r.code == 200
        return r.parsed_response
      end

      alias toots statuses

      def announcements(params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        r = http.get('/api/v1/announcements', {headers: headers})
        raise Ginseng::GatewayError, "Bad response #{r.code}" unless r.code == 200
        return r.parsed_response
      end

      def followers(params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        id = params[:id] || @config['/mastodon/account/id']
        uri = create_uri("/api/v1/accounts/#{id}/followers")
        uri.query_values = {limit: @config['/mastodon/followers/limit']}
        return http.get(uri, {headers: headers})
      end

      def followees(params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        id = params[:id] || @config['/mastodon/account/id']
        uri = create_uri("/api/v1/accounts/#{id}/following")
        uri.query_values = {limit: @config['/mastodon/followees/limit']}
        return http.get(uri, {headers: headers})
      end

      alias following followees

      def filters(params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return http.get('/api/v1/filters', {headers: headers})
      end

      def register_filter(params)
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return http.post('/api/v1/filters', {
          body: {
            phrase: params[:phrase],
            context: params[:context] || [:home, :public],
          }.to_json,
          headers: headers,
        })
      end

      def unregister_filter(id, params = {})
        headers = params[:headers] || {}
        headers['Authorization'] ||= "Bearer #{token}"
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return http.delete("/api/v1/filters/#{id}", {
          body: '{}',
          headers: headers,
        })
      end

      def oauth_client
        unless File.exist?(oauth_client_path)
          r = http.post('/api/v1/apps', {
            body: {
              client_name: package_class.name,
              website: @config['/package/url'],
              redirect_uris: @config['/mastodon/oauth/redirect_uri'],
              scopes: @config['/mastodon/oauth/scopes'].join(' '),
            }.to_json,
          })
          File.write(oauth_client_path, r.parsed_response.to_json)
        end
        return JSON.parse(File.read(oauth_client_path))
      end

      def oauth_uri
        uri = create_uri('/oauth/authorize')
        uri.query_values = {
          client_id: oauth_client['client_id'],
          response_type: 'code',
          redirect_uri: @config['/mastodon/oauth/redirect_uri'],
          scope: @config['/mastodon/oauth/scopes'].join(' '),
        }
        return uri
      end

      def auth(code)
        return http.post('/oauth/token', {
          headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
          body: {
            'grant_type' => 'authorization_code',
            'redirect_uri' => @config['/mastodon/oauth/redirect_uri'],
            'client_id' => oauth_client['client_id'],
            'client_secret' => oauth_client['client_secret'],
            'code' => code,
          },
        })
      end

      def create_streaming_uri(stream = 'user')
        uri = self.uri.clone
        uri.scheme = 'wss'
        uri.path = '/api/v1/streaming'
        uri.query_values = {'access_token' => token, 'stream' => stream}
        return uri
      end

      private

      def default_token
        return @config['/mastodon/token']
      end

      def default_uri
        return Ginseng::URI.parse(@config['/mastodon/url'])
      end
    end
  end
end
