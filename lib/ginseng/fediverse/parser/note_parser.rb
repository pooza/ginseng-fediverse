module Ginseng
  module Fediverse
    class NoteParser < Parser
      include Package

      ATMARK = '__ATMARK__'.freeze
      HASH = '__HASH__'.freeze

      def default_service
        return (MisskeyService.new rescue MeisskeyService.new)
      end

      def to_md
        md = text.dup
        tags.sort_by(&:length).reverse_each do |tag|
          md.gsub!("\##{tag}", "[\\#{HASH}#{tag}](#{service.create_uri("/tags/#{tag}")})")
        end
        accts = self.accts.map(&:to_s).sort_by do |acct|
          v = acct.to_s
          (v.scan(/@/).count * 100_000_000) + v.length
        end
        accts.reverse_each do |acct|
          md.sub!(acct, "[#{acct.gsub('@', ATMARK)}](#{service.create_uri("/#{acct}")})")
        end
        md.gsub!(HASH, '#')
        md.gsub!(ATMARK, '@')
        return Parser.sanitize(md)
      end

      def self.visibility_name(name)
        return visibility_names[name.to_sym] if visibility_names.key?(name.to_sym)
        return name if visibility_names.values.member?(name)
        return visibility_names[:public]
      rescue
        return visibility_names[:public]
      end

      def default_max_length
        return @config['/misskey/note/default_max_length']
      end

      def self.visibility_names
        return {public: 'public'}.merge(
          [:unlisted, :private, :direct].to_h do |name|
            [name, Config.instance["/parser/note/visibility/#{name}/name"]]
          end,
        )
      end
    end
  end
end
