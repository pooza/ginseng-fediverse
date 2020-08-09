module Ginseng
  module Fediverse
    class MeisskeyService < MisskeyService
      include Package

      def announcements(params = {})
        r = http.get('/api/meta', {
          body: {i: token}.to_json,
          headers: create_headers(params[:headers]),
        })
        raise Ginseng::GatewayError, "Bad response #{r.code}" unless r.code == 200
        return r['announcements'].map do |entry|
          {id: Digest::SHA1.hexdigest(entry.to_json), title: entry['title'], text: entry['text']}
        end
      end

      private

      def default_token
        return @config['/meisskey/token']
      end

      def default_uri
        return Ginseng::URI.parse(@config['/meisskey/url'])
      end
    end
  end
end
