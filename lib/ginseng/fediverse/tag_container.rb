module Ginseng
  module Fediverse
    class TagContainer < Array
      include Package
      attr_reader :text

      def push(word)
        @tags = nil
        return super(word.to_s.sub(/^#/, ''))
      end

      def concat(words)
        words.map {|v| push(v)} if words.is_a?(Array)
      end

      alias body text

      def text=(text)
        @tags = nil
        @text = text.nfkc
      end

      alias body= text=

      def count
        return create_tags.count
      end

      def to_s
        return create_tags.join(' ')
      end

      def create_tags
        unless @tags
          @tags = map do |tag|
            tag.gsub(/([a-z0-9]{2,})\s/i, '\\1_').gsub(/\s/, '').to_hashtag
          end
          @tags.uniq!
          @tags.compact!
          @tags.reject! {|v| @text.match?(create_pattern(v))} if @text
        end
        return @tags
      end

      def self.scan(text)
        return TagContainer.new(
          text.scan(Parser.hashtag_pattern).map(&:first),
        )
      end

      private

      def create_pattern(tag)
        return Regexp.new("#{tag.to_hashtag}([^[:word:]]|$)")
      end
    end
  end
end
