module Ginseng
  module Fediverse
    class MeisskeyService < MisskeyService
      include Package

      def announcements(params = {})
        response = http.get('/api/meta', {
          body: {i: token}.to_json,
          headers: create_headers(params[:headers]),
        })
        return response['announcements'].map do |entry|
          {
            id: entry.to_json.adler32,
            title: entry['title'],
            text: entry['text'],
            content: entry['text'],
          }
        end
      end

      def default_token
        return @config['/meisskey/token']
      end

      private

      def default_uri
        return Ginseng::URI.parse(@config['/meisskey/url'])
      end
    end
  end
end
