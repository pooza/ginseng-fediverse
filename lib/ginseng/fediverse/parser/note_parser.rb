module Ginseng
  module Fediverse
    class NoteParser < Parser
      include Package

      ATMARK = '__ATMARK__'.freeze
      HASH = '__HASH__'.freeze

      def initialize(text = '')
        super
        @service = MisskeyService.new
      end

      def to_md
        md = text.clone
        tags.sort_by(&:length).reverse_each do |tag|
          md.gsub!("\##{tag}", "[#{HASH}#{tag}](#{@service.create_uri("/tags/#{tag}")})")
        end
        accts = self.accts.map(&:to_s).sort_by do |acct|
          v = acct.to_s
          v.scan(/@/).count * 100_000_000 + v.length
        end
        accts.reverse_each do |acct|
          md.sub!(acct, "[#{acct.gsub('@', ATMARK)}](#{@service.create_uri("/#{acct}")})")
        end
        md.gsub!(HASH, '#')
        md.gsub!(ATMARK, '@')
        return Parser.sanitize(md)
      end

      def max_length
        return @config['/misskey/note/max_length']
      end
    end
  end
end
