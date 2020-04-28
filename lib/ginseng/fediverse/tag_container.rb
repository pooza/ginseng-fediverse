require 'unicode'
require 'digest/sha1'

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
        @text = Unicode.nfkc(text)
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
            tag.gsub!(/\s/, '') unless /^[a-z0-9\s]+$/i.match?(tag)
            Service.create_tag(tag)
          end
          @tags.uniq!
          @tags.compact!
          @tags.delete_if {|v| @text =~ create_pattern(v)} if @text
        end
        return @tags
      end

      def self.scan(text)
        return text.scan(Parser.hashtag_pattern).map(&:first)
      end

      def self.tweak(text)
        links = {}
        Ginseng::URI.scan(text).each do |uri|
          key = Digest::SHA1.hexdigest(uri.to_s)
          links[key] = uri.to_s
          text.sub!(uri.to_s, key)
        end
        text.gsub!(/ *#/, ' #')
        text.sub!(/^ #/, '#')
        links.each do |key, link|
          text.sub!(key, link)
        end
        return text
      end

      private

      def create_pattern(tag)
        tag = Service.create_tag(tag) unless /^#/.match?(tag)
        return Regexp.new("#{tag}([^[:word:]]|$)")
      end
    end
  end
end
