module Ginseng
  module Fediverse
    class MulukhiyaService
      include Package

      def initialize(uri = nil)
        uri = URI.parse(uri.to_s) unless uri.is_a?(URI)
        @http = http_class.new
        # ⚠ `Service` を継承しないので、ガードはここでも挿す (#320)。挿し方の理由は `Service#initialize`。
        # 🔴 `search_hashtags` は本文を POST するので、3xx は追わずに `GatewayError` になる。
        @http.guard_redirects!
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
