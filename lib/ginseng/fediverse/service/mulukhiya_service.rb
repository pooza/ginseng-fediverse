module Ginseng
  module Fediverse
    class MulukhiyaService
      include Package
      attr_reader :base_uri

      def initialize(uri = nil)
        uri = Ginseng::URI.parse(uri.to_s) unless uri.is_a?(Ginseng::URI)
        @http = http_class.new
        @http.base_uri = uri if uri
      end

      def about
        return @http.get('/mulukhiya/api/about')
      end

      def health
        return @http.get('/mulukhiya/api/health')
      end

      def search_hashtags(text)
        uri = @http.create_uri('/mulukhiya/api/tagging/tag/search')
        uri.query_values = {q: text}
        tags = []
        @http.get(uri).each_value do |value|
          tags.concat(value['words'])
        end
        return tags.uniq.compact
      end
    end
  end
end
