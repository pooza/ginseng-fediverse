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
      end
    end
  end
end
