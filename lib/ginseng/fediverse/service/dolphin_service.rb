module Ginseng
  module Fediverse
    class DolphinService < MisskeyService
      include Package

      def initialize(uri = nil, token = nil)
        super
        @http.base_uri = Ginseng::URI.parse(uri || @config['/dolphin/url'])
      end

      def announcements(params = {})
        raise Ginseng::GatewayError, 'Dolphin does not respond to announcements.'
      end
    end
  end
end
