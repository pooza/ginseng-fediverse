module Ginseng
  module Fediverse
    class DolphinService < MisskeyService
      include Package

      def announcements(params = {})
        return nil
      end

      private

      def default_token
        return @config['/dolphin/token']
      end

      def default_uri
        return Ginseng::URI.parse(@config['/dolphin/url'])
      end
    end
  end
end
