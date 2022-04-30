require 'nokogiri'

module Ginseng
  module Fediverse
    include Package

    class Parser
      include Package
      attr_reader :text, :body, :footer, :footer_tags
      attr_accessor :max_length, :service

      def initialize(text = '')
        @config = config_class.instance
        @logger = logger_class.new
        @service = (default_service rescue nil)
        @max_length = (default_max_length rescue nil)
        @footer_tags = tag_container_class.new
        self.text = text || ''
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
        @text = text.to_s.strip
        @params = nil
        @footer_tags.clear
        lines = self.class.sanitize(text).each_line.to_a
        lines.dup.reverse_each do |line|
          break unless line.match?(/^[[:blank:]]*(#[^[:blank:]]+[[:blank:]]?)+[[:blank:]]*$/)
          @footer_tags.merge(lines.pop.strip.split(/[[:blank:]]+/))
        end
        @body = lines.map(&:chomp).join("\n").strip
        @footer = @footer_tags.map(&:to_hashtag).join(' ')
      end

      def to_md
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def nowplaying?
        return /#nowplaying[[:blank:]]/i.match?(text)
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
        return tag_container_class.scan(text)
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
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def default_service
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def self.sanitize(text)
        text = text.dup
        text.delete!("\n") if text.match?(/<br.*?>/)
        text.gsub!(/[[:blank:]]*<br.*?>/, "\n")
        text.gsub!(%r{[[:blank:]]*</p.*?>}, "\n\n")
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
