require 'nokogiri'

module Ginseng
  module Fediverse
    class Parser
      include Package
      attr_reader :text

      def initialize(text = '')
        self.text = text
        @config = config_class.instance
        @logger = logger_class.new
      end

      alias to_s text

      def nokogiri
        @nokogiri ||= Nokogiri::HTML.parse(text, nil, 'utf-8')
        return @nokogiri
      end

      def accts
        return enum_for(__method__) unless block_given?
        text.scan(Parser.acct_pattern).map(&:first).each do |acct|
          yield Acct.new(acct)
        end
      end

      def uris(&block)
        return enum_for(__method__) unless block
        Ginseng::URI.scan(text).each(&block)
      end

      def text=(text)
        @text = text.to_s
        @params = nil
        @all_tags = nil
      end

      def to_md
        raise Ginseng::ImplementError, "'#{__method__}' not implemented"
      end

      def length
        return text.length
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
        return TagContainer.scan(text)
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

      def max_length
        raise Ginseng::ImplementError, "'#{__method__}' not implemented"
      end

      def self.sanitize(text)
        text = text.clone
        text.gsub!("\n", '') if text.match?(%r{<br.*?>}) 
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
