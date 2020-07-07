module Ginseng
  module Fediverse
    class Acct
      include Package
      attr_reader :contents, :username, :host

      def initialize(contents)
        @contents = contents
        @username, @host = @contents.sub(/^@/, '').split('@')
        @config = config_class.instance
      end

      alias to_s contents

      def valid?
        return @contents.match?(Acct.pattern)
      end

      def self.pattern
        return Parser.acct_pattern
      end
    end
  end
end
