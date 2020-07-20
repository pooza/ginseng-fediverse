require 'digest/sha2'

module Ginseng
  module Fediverse
    class MisskeyService < Service
      include Package

      def post(body, params = {})
        body = {text: body.to_s} unless body.is_a?(Hash)
        headers = params[:headers] || {}
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        body[:i] ||= token
        return http.post('/api/notes/create', {body: body.to_json, headers: headers})
      end

      alias note post

      def favourite(id, params = {})
        headers = params[:headers] || {}
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return http.post('/api/notes/favorites/create', {
          body: {noteId: id, i: token}.to_json,
          headers: headers,
        })
      end

      alias fav favourite

      alias bookmark favourite

      def upload(path, params = {})
        headers = params[:headers] || {}
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        body = {force: 'true', i: token}
        response = http.upload('/api/drive/files/create', path, headers, body)
        return response if params[:response] == :raw
        return JSON.parse(response.body)['id']
      end

      def statuses(params = {})
        headers = params[:headers] || {}
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        r = http.post('/api/users/notes', {
          body: {userId: params[:account_id], i: token}.to_json,
          headers: headers,
        })
        raise Ginseng::GatewayError, "Bad response #{r.code}" unless r.code == 200
        return r.parsed_response
      end

      alias notes statuses

      def fetch_status(id, params = {})
        headers = params[:headers] || {}
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return http.post('/api/notes/show', {
          body: {noteId: id, i: token}.to_json,
          headers: headers,
        })
      end

      alias fetch_note fetch_status

      def fetch_attachment(id, params = {})
        headers = params[:headers] || {}
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return http.post('/api/drive/files/show', {
          body: {fileId: id, i: token}.to_json,
          headers: headers,
        })
      end

      def oauth_client
        unless File.exist?(oauth_client_path)
          r = http.post('/api/app/create', {
            body: {
              name: package_class.name,
              description: @config['/package/description'],
              permission: @config['/misskey/oauth/permission'],
              callbackUrl: create_uri(@config['/misskey/oauth/callback_url']).to_s,
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
        r = http.post('/api/auth/session/generate', {
          body: {
            appSecret: oauth_client['secret'],
          }.to_json,
        })
        return URI.parse(r['url'])
      end

      def auth(token)
        return http.post('/api/auth/session/userkey', {
          body: {
            appSecret: oauth_client['secret'],
            token: token,
          }.to_json,
        })
      end

      def announcements(params = {})
        headers = params[:headers] || {}
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        r = http.post('/api/announcements', {
          body: {i: token}.to_json,
          headers: headers,
        })
        raise Ginseng::GatewayError, "Bad response #{r.code}" unless r.code == 200
        return r.parsed_response
      end

      private

      def default_token
        return @config['/misskey/token']
      end

      def default_uri
        return Ginseng::URI.parse(@config['/misskey/url'])
      end
    end
  end
end
