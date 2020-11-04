require 'digest/sha2'

module Ginseng
  module Fediverse
    class MisskeyService < Service
      include Package

      def post(body, params = {})
        body = {text: body.to_s} unless body.is_a?(Hash)
        body[:i] ||= token
        return http.post('/api/notes/create', {
          body: body.to_json,
          headers: create_headers(params[:headers]),
        })
      end

      alias note post

      def say(body, params = {})
        body = {text: body.to_s} unless body.is_a?(Hash)
        body[:i] ||= token
        return http.post('/api/messaging/messages/create', {
          body: body.to_json,
          headers: create_headers(params[:headers]),
        })
      end

      def favourite(id, params = {})
        return http.post('/api/notes/favorites/create', {
          body: {noteId: id, i: token}.to_json,
          headers: create_headers(params[:headers]),
        })
      end

      alias fav favourite

      alias bookmark favourite

      def upload(path, params = {})
        params[:response] ||= :raw
        body = {force: 'true', i: token}
        response = http.upload(
          '/api/drive/files/create',
          path,
          create_headers(params[:headers]),
          body,
        )
        return response if params[:response] == :raw
        return JSON.parse(response.body)['id']
      end

      def statuses(params = {})
        response = http.post('/api/users/notes', {
          body: {userId: params[:account_id], i: token}.to_json,
          headers: create_headers(params[:headers]),
        })
        return response.parsed_response
      end

      alias notes statuses

      def fetch_status(id, params = {})
        return http.post('/api/notes/show', {
          body: {noteId: id, i: token}.to_json,
          headers: create_headers(params[:headers]),
        })
      end

      alias fetch_note fetch_status

      def fetch_attachment(id, params = {})
        return http.post('/api/drive/files/show', {
          body: {fileId: id, i: token}.to_json,
          headers: create_headers(params[:headers]),
        })
      end

      def oauth_client
        unless File.exist?(oauth_client_path)
          response = http.post('/api/app/create', {
            body: {
              name: package_class.name,
              description: @config['/package/description'],
              permission: @config['/misskey/oauth/permission'],
              callbackUrl: create_uri(@config['/misskey/oauth/callback_url']).to_s,
            }.to_json,
          })
          File.write(oauth_client_path, response.body)
        end
        return JSON.parse(File.read(oauth_client_path))
      end

      def create_access_token(token)
        return Digest::SHA256.hexdigest(token + oauth_client['secret'])
      end

      def oauth_uri
        response = http.post('/api/auth/session/generate', {
          body: {appSecret: oauth_client['secret']}.to_json,
        })
        return Ginseng::URI.parse(response['url'])
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
        response = http.post('/api/announcements', {
          body: {i: token}.to_json,
          headers: headers,
        })
        return response.parsed_response.map do |announcement|
          entry = announcement.deep_symbolize_keys
          entry[:imate_url] = entry[:imageUrl]
          entry
        end
      end

      def create_tag_uri(tag)
        return create_uri("/tags/#{tag.to_hashtag_base}")
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
