module Ginseng
  module Fediverse
    class TootParserTest < TestCase
      def setup
        @parser = TootParser.new
      end

      def test_too_long?
        @parser.text = 'ローリン♪ローリン♪ココロにズッキュン'
        assert_false(@parser.too_long?)

        @parser.text = '0' * @parser.max_length
        assert_false(@parser.too_long?)

        @parser.text = '0' * (@parser.max_length + 1)
        assert(@parser.too_long?)
      end

      def test_accts
        @parser.text = '@pooza @poozZa @pooza@mstdn.example.com pooza@b-shock.org'
        @parser.accts do |acct|
          assert_kind_of(Acct, acct)
          assert(acct.valid?)
        end
        assert_equal(@parser.accts.map(&:to_s), ['@pooza', '@poozZa', '@pooza@mstdn.example.com'])
      end

      def test_uris
        @parser.text = 'https://www.google.co.jp https://mstdn.b-shock.co.jp'
        @parser.uris do |uri|
          assert_kind_of(Ginseng::URI, uri)
          assert(uri.absolute?)
        end
        assert_equal(@parser.uris.map(&:to_s), ['https://www.google.co.jp', 'https://mstdn.b-shock.co.jp'])
      end

      def test_to_md
        assert_kind_of(String, @parser.to_md)
      end

      def test_visibility_names
        assert_kind_of(Hash, TootParser.visibility_names)
        pp TootParser.visibility_names
      end

      def test_visibility_name
        ['public', 'unlisted', 'private', 'direct'].each do |key|
          assert_kind_of(String, TootParser.visibility_name(key))
        end
      end
    end
  end
end
