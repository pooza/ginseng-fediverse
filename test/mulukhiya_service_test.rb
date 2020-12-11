module Ginseng
  module Fediverse
    class MulukhiyaServiceTest < TestCase
      def setup
        @config = Config.instance
        @mulukhiya = MulukhiyaService.new(@config['/mulukhiya/url'])
      end

      def test_about
        response = @mulukhiya.about
        assert_kind_of(HTTParty::Response, response)
        assert_equal(response.code, 200)
      end

      def test_health
        response = @mulukhiya.health
        assert_kind_of(HTTParty::Response, response)
        assert_equal(response.code, 200)
      end

      def test_search_hashtags
        assert_kind_of(Array, @mulukhiya.search_hashtags('キュアソードはドキプリに登場。'))
      end
    end
  end
end
