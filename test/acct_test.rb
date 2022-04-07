module Ginseng
  module Fediverse
    class AcctTest < TestCase
      def setup
        @acct = Acct.new('@pooza@example.com')
      end

      def test_valid?
        assert_predicate(@acct, :valid?)
      end

      def test_username
        assert_equal('pooza', @acct.username)
      end

      def test_host
        assert_equal('example.com', @acct.host)
      end

      def test_pattern
        assert_kind_of(Regexp, Acct.pattern)
      end
    end
  end
end
