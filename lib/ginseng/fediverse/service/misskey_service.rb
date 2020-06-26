require 'digest/sha2'

module Ginseng
  module Fediverse
    class MisskeyService < Service
      include Package

      def initialize(uri = nil, token = nil)
        super
        @token = token || @config['/misskey/token']
        @http.base_uri = Ginseng::URI.parse(uri || @config['/misskey/url'])
      end

      def fetch_status(id)
        response = @http.get("/mulukhiya/note/#{id}")
        raise Ginseng::GatewayError, response['message'] unless response.code == 200
        return response
      end

      alias fetch_note fetch_status

      def post(body, params = {})
        body = {text: body.to_s} unless body.is_a?(Hash)
        headers = params[:headers] || {}
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        body[:i] ||= @token
        return @http.post('/api/notes/create', {body: body.to_json, headers: headers})
      end

      alias note post

      def favourite(id, params = {})
        headers = params[:headers] || {}
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return @http.post('/api/notes/favorites/create', {
          body: {noteId: id, i: @token}.to_json,
          headers: headers,
        })
      end

      alias fav favourite

      alias bookmark favourite

      def upload(path, params = {})
        headers = params[:headers] || {}
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        body = {force: 'true', i: @token}
        response = @http.upload('/api/drive/files/create', path, headers, body)
        return response if params[:response] == :raw
        return JSON.parse(response.body)['id']
      end

      def oauth_client
        unless File.exist?(oauth_client_path)
          r = @http.post('/api/app/create', {
            body: {
              name: package_class.name,
              description: @config['/package/description'],
              permission: @config['/misskey/oauth/permission'],
              callbackUrl: @http.create_uri(@config['/misskey/oauth/callback_url']).to_s,
            }.to_json,
          })
          File.write(oauth_client_path, r.parsed_response.to_json)
        end
        return JSON.parse(File.read(oauth_client_path))
      end

      def create_access_token(token)
        return Digest::SHA256.hexdigest(token + oauth_client['secret'])
      end

      def oauth_uri
        r = @http.post('/api/auth/session/generate', {
          body: {
            appSecret: oauth_client['secret'],
          }.to_json,
        })
        return URI.parse(r['url'])
      end

      def auth(token)
        return @http.post('/api/auth/session/userkey', {
          body: {
            appSecret: oauth_client['secret'],
            token: token,
          }.to_json,
        })
      end

      def filters
        raise Ginseng::GatewayError, 'Misskey does not support to filter.'
      end

      def announcements(params = {})
        headers = params[:headers] || {}
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return @http.post('/api/announcements', {
          body: {i: @token}.to_json,
          headers: headers,
        })
      end

      def create_uri(href = '/api/notes/create')
        return @http.create_uri(href)
      end
    end
  end
end
