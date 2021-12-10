module Ginseng
  module Fediverse
    class TootParser < Parser
      include Package

      def to_md
        md = text.dup
        ['.u-url', '.hashtag'].each do |selector|
          nokogiri.css(selector).each do |link|
            md.gsub!(link.to_s, "[\\#{link.inner_text}](#{link.attributes['href'].value})")
          rescue => e
            @logger.error(error: e.message, link: link.to_s)
          end
        end
        return Parser.sanitize(md)
      end

      def max_length
        return @config['/mastodon/toot/max_length']
      end

      def self.visibility_name(name)
        return visibility_names[name.to_sym] if visibility_names.key?(name.to_sym)
        return name if visibility_names.values.member?(name)
        return 'public'
      rescue
        return 'public'
      end

      def self.visibility_names
        return {public: 'public'}.merge(
          [:unlisted, :private, :direct].to_h do |name|
            [name, Config.instance["/parser/toot/visibility/#{name}"]]
          end,
        )
      end
    end
  end
end
