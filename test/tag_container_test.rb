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
        @container.push('カレー担々麺')
        @container.push('コスモグミ')

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

      def test_push_blank
        @container.push('')
        @container.push(nil)
        @container.push('#')

        assert_equal(Set[], @container)
        assert_equal(Set[], @container.create_tags)
      end

      def test_new_with_blank
        container = TagContainer.new(['foo', '', nil, '#', 'bar'])

        assert_equal(Set['foo', 'bar'], container)
        assert_equal(Set['#foo', '#bar'], container.create_tags)
      end

      def test_scan
        assert_equal(TagContainer.scan('#フワ #プルンス'), Set['フワ', 'プルンス'])
      end

      def test_delete
        @container.push('実況')
        @container.push('precure_fun')

        assert_equal(@container.delete('実況'), @container)
        assert_equal(Set['precure_fun'], @container)
      end

      def test_delete_case_insensitive
        @container.push('Makoto')
        @container.push('precure_fun')

        assert_equal(@container.delete('MAKOTO'), @container)
        assert_equal(Set['precure_fun'], @container)
      end

      def test_delete_missing
        @container.push('precure_fun')

        assert_nil(@container.delete('実況'))
        assert_equal(Set['precure_fun'], @container)
      end

      def test_select_bang_with_short_tags
        @container.push('実況')
        @container.push('precure_fun')

        assert_nothing_raised do
          @container.select! {|v| v.to_s.length > 2}
        end
        assert_equal(Set['precure_fun'], @container)
      end
    end
  end
end
