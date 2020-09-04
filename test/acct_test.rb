module Ginseng
  module Fediverse
    class AcctTest < Ginseng::TestCase
      def setup
        @acct = Acct.new('@pooza@example.com')
      end

      def test_valid?
        assert(@acct.valid?)
      end

      def test_username
        assert_equal(@acct.username, 'pooza')
      end

      def test_host
        assert_equal(@acct.host, 'example.com')
      end

      def test_pattern
        assert_kind_of(Regexp, Acct.pattern)
      end
    end
  end
end
