module Ginseng
  module Fediverse
    class TootURITest < TestCase
      def setup
        @uri = TootURI.parse('https://precure.ml/web/statuses/101118840135913675')
      end

      def test_id
        assert_equal(@uri.id, 101_118_840_135_913_675)
      end

      def test_service
        assert_kind_of(MastodonService, @uri.service)
      end
    end
  end
end
