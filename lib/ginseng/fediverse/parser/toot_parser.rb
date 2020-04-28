module Ginseng
  module Fediverse
    class TootParser < Parser
      include Package

      def to_md
        md = text.clone
        ['.u-url', '.hashtag'].each do |style_class|
          nokogiri.css(style_class).each do |link|
            md.gsub!(link.to_s, "[#{link.inner_text}](#{link.attributes['href'].value})")
          rescue => e
            @logger.error(Ginseng::Error.create(e).to_h.merge(link: link.to_s))
          end
        end
        return Parser.sanitize(md)
      end

      def max_length
        length = @config['/mastodon/toot/max_length']
        length = length - all_tags.join(' ').length - 1 if create_tags.present?
        return length
      end
    end
  end
end
