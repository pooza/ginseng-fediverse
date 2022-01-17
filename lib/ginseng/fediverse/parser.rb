require 'nokogiri'

module Ginseng
  module Fediverse
    class Parser
      include Package
      attr_reader :text
      attr_accessor :max_length

      def initialize(text = '')
        self.text = text
        @config = config_class.instance
        @logger = logger_class.new
        @max_length = default_max_length
      end

      alias to_s text

      def nokogiri
        return text.nokogiri
      end

      def accts(&block)
        return enum_for(__method__) unless block
        text.scan(Parser.acct_pattern).map(&:first).map {|v| Acct.new(v)}.each(&block)
      end

      def uris(&block)
        return enum_for(__method__) unless block
        URI.scan(text).each(&block)
      end

      def text=(text)
        @text = text.to_s.dup
        @params = nil
        @all_tags = nil
      end

      def to_md
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def nowplaying?
        return /#nowplaying\s/i.match?(text)
      end

      def service
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def length
        length = text.length
        length -= uris.sum {|v| v.to_s.length - service.characters_reserved_per_url}
        length -= accts.sum {|v| v.to_s.length - v.username.length - 1}
        return length
      end

      alias size length

      def too_long?
        return max_length < length
      end

      def exec
        if @params.nil?
          @params = YAML.safe_load(text)
          @params = JSON.parse(text) unless @params.is_a?(Hash)
          @params = false unless @params.is_a?(Hash)
        end
        return @params || nil
      rescue Psych::SyntaxError, JSON::ParserError
        return nil
      rescue Psych::Exception, JSON::JSONError => e
        return @logger.error(e)
      end

      alias params exec

      def hashtags
        return TagContainer.new(TagContainer.scan(text))
      end

      alias tags hashtags

      def command?
        return true if params.key?('command')
        return true if text.start_with?('c:') && params.key?('c')
        return false
      rescue
        return false
      end

      def command_name
        if text.start_with?('c:')
          params['command'] ||= params['c']
          params.delete('c')
        end
        return params['command']
      rescue
        return nil
      end

      alias command command_name

      def to_sanitized
        return Parser.sanitize(text)
      end

      def default_max_length
        return nil
      end

      def self.sanitize(text)
        text = text.dup
        text.delete!("\n") if text.match?(/<br.*?>/)
        text.gsub!(/\s*<br.*?>/, "\n")
        text.gsub!(%r{\s*</p.*?>}, "\n\n")
        text.gsub!(/<p.*?>/, '')
        text.sanitize!
        return text.strip
      end

      def self.hashtag_pattern
        return Regexp.new(Config.instance['/hashtag/pattern'], Regexp::IGNORECASE)
      end

      def self.acct_pattern
        return Regexp.new(Config.instance['/acct/pattern'], Regexp::IGNORECASE)
      end
    end
  end
end
