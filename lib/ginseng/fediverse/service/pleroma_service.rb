module Ginseng
  module Fediverse
    class PleromaService < MastodonService
      include Package

      def initialize(uri = nil, token = nil)
        super
        @token = token || @config['/pleroma/token']
        @http.base_uri = Ginseng::URI.parse(uri || @config['/pleroma/url'])
      end

      def filters
        raise Ginseng::GatewayError, 'Pleroma does not support to filter.'
      end

      def announcements(params = {})
        raise Ginseng::GatewayError, 'Pleroma does not support to announcements.'
      end

      def oauth_client
        unless File.exist?(oauth_client_path)
          r = @http.post('/api/v1/apps', {
            body: {
              client_name: package_class.name,
              website: @config['/package/url'],
              redirect_uris: @config['/pleroma/oauth/redirect_uri'],
              scopes: @config['/pleroma/oauth/scopes'].join(' '),
            }.to_json,
          })
          File.write(oauth_client_path, r.parsed_response.to_json)
        end
        return JSON.parse(File.read(oauth_client_path))
      end

      def oauth_uri
        uri = @http.create_uri('/oauth/authorize')
        uri.query_values = {
          client_id: oauth_client['client_id'],
          response_type: 'code',
          redirect_uri: @config['/pleroma/oauth/redirect_uri'],
          scope: @config['/pleroma/oauth/scopes'].join(' '),
        }
        return uri
      end

      def auth(code)
        return @http.post('/oauth/token', {
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
    end
  end
end
