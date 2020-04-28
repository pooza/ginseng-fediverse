module Ginseng
  module Fediverse
    class TootParser < Parser
      include Package

      def max_length
        return @config['/mastodon/toot/max_length']
      end
    end
  end
end
