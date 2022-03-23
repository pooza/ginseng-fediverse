module Ginseng
  module Fediverse
    class TootParser < Parser
      include Package

      def default_service
        return (MastodonService.new rescue PleromaService.new)
      end

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

      def self.visibility_name(name)
        return visibility_names[name.to_sym] if visibility_names.key?(name.to_sym)
        return name.to_s if visibility_names.values.member?(name.to_s)
        return 'public'
      rescue
        return 'public'
      end

      def self.visibility_names
        names = [:public, :unlisted, :private, :direct].to_h do |name|
          [name.to_sym, Config.instance["/parser/toot/visibility/#{name}/name"].to_s]
        end
        return names.merge(names.to_h {|_, v| [v.to_sym, v.to_s]})
      end

      def self.visibility_icon(name)
        return visibility_icons[name.to_sym] if visibility_icons.key?(name.to_sym)
        return name.to_s if visibility_icons.values.member?(name.to_s)
        return nil
      rescue
        return nil
      end

      def self.visibility_icons
        config = Config.instance
        names = [:public, :unlisted, :private, :direct].to_h do |name|
          [name.to_sym, config["/parser/toot/visibility/#{name}/icon"].to_s]
        end
        return names.merge([:public, :unlisted, :private, :direct].to_h do |name|
          [
            config["/parser/toot/visibility/#{name}/name"].to_sym,
            config["/parser/toot/visibility/#{name}/icon"].to_s,
          ]
        end)
      end

      def default_max_length
        return @config['/mastodon/toot/default_max_length']
      end
    end
  end
end
