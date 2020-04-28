module Ginseng
  module Fediverse
    class NoteParser < Parser
      include Package
      ATMARK = '__ATMARK__'.freeze
      HASH = '__HASH__'.freeze

      def max_length
        return @config['/misskey/note/max_length']
      end
    end
  end
end
