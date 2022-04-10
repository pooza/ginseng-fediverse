module Ginseng
  module Fediverse
    class TagContainer < Set
      include Package
      attr_reader :text

      def add(word)
        @tags = nil
        return super(normalize(word.to_s))
      end

      alias push add

      def member?(tag)
        return super(tag.to_s.to_hashtag_base)
      end

      def merge(words)
        words.each {|v| add(v)}
      end

      alias concat merge

      def normalize(word)
        return word.sub(/^#/, '')
      end

      alias body text

      def delete(tag)
        reject! {|v| v.casecmp(tag).zero?}
      end

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
          tags = map do |tag|
            tag.gsub(/([a-z0-9]{2,})[[:blank:]]/i, '\\1_').gsub(/[[:blank:]]/, '').to_hashtag
          end
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
