module Ginseng
  module Fediverse
    class DolphinService < MisskeyService
      include Package

      def initialize(uri = nil, token = nil)
        super
        @token = token || @config['/dolphin/token']
        @http.base_uri = Ginseng::URI.parse(uri || @config['/dolphin/url'])
      end

      def filters
        raise Ginseng::GatewayError, 'Dolphin does not support to filter.'
      end

      def announcements(params = {})
        raise Ginseng::GatewayError, 'Dolphin does not support to announcements.'
      end
    end
  end
end
