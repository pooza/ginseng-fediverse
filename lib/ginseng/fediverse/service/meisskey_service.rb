module Ginseng
  module Fediverse
    class MeisskeyService < MisskeyService
      include Package

      def announcements(params = {})
        return nil
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
