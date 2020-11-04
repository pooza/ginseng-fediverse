module Ginseng
  module Fediverse
    class PleromaService < MastodonService
      include Package

      def say(body, params = {})
        params[:chat_id] ||= body[:chat_id]
        return http.post("/api/v1/pleroma/chats/#{params[:chat_id]}/messages", {
          body: body.to_json,
          headers: create_headers(params[:headers]),
        })
      end

      def upload(path, params = {})
        params[:response] ||= :raw
        response = http.upload('/api/v1/media', path, create_headers(params[:headers]))
        return response if params[:response] == :raw
        return JSON.parse(response.body)['id']
      end

      def announcements(params = {})
        return nil
      end

      def oauth_client
        unless File.exist?(oauth_client_path)
          response = http.post('/api/v1/apps', {
            body: {
              client_name: package_class.name,
              website: @config['/package/url'],
              redirect_uris: @config['/pleroma/oauth/redirect_uri'],
              scopes: @config['/pleroma/oauth/scopes'].join(' '),
            }.to_json,
          })
          File.write(oauth_client_path, response.body)
        end
        return JSON.parse(File.read(oauth_client_path))
      end

      def oauth_uri
        uri = create_uri('/oauth/authorize')
        uri.query_values = {
          client_id: oauth_client['client_id'],
          response_type: 'code',
          redirect_uri: @config['/pleroma/oauth/redirect_uri'],
          scope: @config['/pleroma/oauth/scopes'].join(' '),
        }
        return uri
      end

      def auth(code)
        return http.post('/oauth/token', {
          headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
          body: {
            'grant_type' => 'authorization_code',
            'redirect_uri' => @config['/pleroma/oauth/redirect_uri'],
            'client_id' => oauth_client['client_id'],
            'client_secret' => oauth_client['client_secret'],
            'code' => code,
          },
        })
      end

      def nodeinfo
        unless @nodeinfo
          @nodeinfo = http.get('/api/v1/instance').parsed_response
          @nodeinfo['metadata'] = {
            'nodeName' => @nodeinfo['title'],
            'maintainer' => {
              'name' => @nodeinfo['email'],
              'email' => @nodeinfo['email'],
            },
          }
        end
        return @nodeinfo
      end

      alias info nodeinfo

      private

      def default_token
        return @config['/pleroma/token']
      end

      def default_uri
        return Ginseng::URI.parse(@config['/pleroma/url'])
      end
    end
  end
end
