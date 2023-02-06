module Ginseng
  module Fediverse
    class TagContainerTest < TestCase
      def setup
        @container = TagContainer.new
      end

      def test_push
        assert_equal(@container.push(111), Set['111'])
      end

      def test_create_tags
        @container.push('カレー担々麺', 'コスモグミ')

        assert_equal(@container.create_tags, Set['#カレー担々麺', '#コスモグミ'])

        @container.push('剣崎 真琴')
        @container.push('Makoto Kenzaki')

        assert_equal(@container.create_tags, Set['#カレー担々麺', '#コスモグミ', '#剣崎真琴', '#Makoto_Kenzaki'])

        @container.clear
        @container.push('武田 信玄')

        assert_equal(@container.create_tags, Set['#武田信玄'])

        @container.clear
        @container.push('Yes!プリキュア5 GoGo!')

        assert_equal(@container.create_tags, Set['#Yes_プリキュア5GoGo'])

        @container.clear
        @container.push('よにんでSUPER TEUCHI STATION ONLINE')

        assert_equal(@container.create_tags, Set['#よにんでSUPER_TEUCHI_STATION_ONLINE'])
      end

      def test_scan
        assert_equal(TagContainer.scan('#フワ #プルンス'), Set['フワ', 'プルンス'])
      end
    end
  end
end
