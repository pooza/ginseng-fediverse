module Ginseng
  module Fediverse
    class NoteParser < Parser
      include Package

      def max_length
        return @config['/misskey/note/max_length']
      end
    end
  end
end
