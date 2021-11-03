module Ginseng
  module Fediverse
    class MulukhiyaService
      include Package

      def initialize(uri = nil)
        uri = Ginseng::URI.parse(uri.to_s) unless uri.is_a?(Ginseng::URI)
        @http = http_class.new
        @http.base_uri = uri if uri
      end

      def base_uri
        return @http.base_uri
      end

      def about
        return @http.get('/mulukhiya/api/about')
      end

      def health
        return @http.get('/mulukhiya/api/health')
      end

      def search_hashtags(text)
        params = {body: {q: text.sanitize}}
        tags = []
        @http.post('/mulukhiya/api/tagging/tag/search', params).each_value do |entry|
          tags.concat(entry['words'])
        end
        return tags.compact.to_set
      end
    end
  end
end
