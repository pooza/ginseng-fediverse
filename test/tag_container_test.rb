module Ginseng
  module Fediverse
    class TagContainerTest < TestCase
      def setup
        @container = TagContainer.new
      end

      def test_push
        assert_equal(@container.push(111), ['111'])
      end

      def test_create_tags
        @container.concat(['カレー担々麺', 'コスモグミ'])
        assert_equal(@container.create_tags, ['#カレー担々麺', '#コスモグミ'])

        @container.push('剣崎 真琴')
        @container.push('Makoto Kenzaki')
        assert_equal(@container.create_tags, ['#カレー担々麺', '#コスモグミ', '#剣崎真琴', '#Makoto_Kenzaki'])

        @container.clear
        @container.push('武田 信玄')
        assert_equal(@container.create_tags, ['#武田信玄'])

        @container.clear
        @container.push('Yes!プリキュア5 GoGo!')
        assert_equal(@container.create_tags, ['#Yes_プリキュア5GoGo'])

        @container.clear
        @container.push('よにんでSUPER TEUCHI STATION ONLINE')
        assert_equal(@container.create_tags, ['#よにんでSUPER_TEUCHI_STATION_ONLINE'])
      end
    end
  end
end
