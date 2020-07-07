require 'nokogiri'

module Ginseng
  module Fediverse
    class TootParser < Parser
      include Package

      def to_md
        md = text.clone
        ['.u-url', '.hashtag'].each do |selector|
          nokogiri.css(selector).each do |link|
            md.gsub!(link.to_s, "[#{link.inner_text}](#{link.attributes['href'].value})")
          rescue => e
            @logger.error(error: e.message, link: link.to_s)
          end
        end
        return Parser.sanitize(md)
      end

      def max_length
        return @config['/mastodon/toot/max_length']
      end
    end
  end
end
