module Ginseng
  module Fediverse
    class TagContainer < Set
      include Package
      attr_reader :text

      def add(word)
        @tags = nil
        return super(word.to_s.sub(/^#/, ''))
      end

      alias push add

      def merge(words)
        words.each {|v| add(v)}
      end

      alias concat merge

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

      def member?(item)
        return super(item.to_hashtag_base)
      end

      def create_tags
        unless @tags
          tags = map {|v| v.gsub(/([a-z0-9]{2,})\s/i, '\\1_').gsub(/\s/, '').to_hashtag}
          tags.compact!
          tags.reject! {|v| @text.match?(create_pattern(v))} if @text
          @tags = tags.to_set
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
