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

      def test_nokogiri
        assert_kind_of(
          [Nokogiri::HTML4::Document, Nokogiri::HTML5::Document, Nokogiri::XML::Document],
          @parser.nokogiri,
        )
      end

      def test_length
        @parser.text = 'ローリン♪ローリン♪ココロにズッキュン'
        assert_equal(@parser.length, 19)

        @parser.text = '@admin ローリン♪ローリン♪ココロにズッキュン'
        assert_equal(@parser.length, 26)

        @parser.text = '@admin@mstdn.example.com ローリン♪ローリン♪ココロにズッキュン'
        assert_equal(@parser.length, 26)

        @parser.text = 'ローリン♪ローリン♪ココロにズッキュン https://mstdn.example.com'
        assert_equal(@parser.length, 43)

        @parser.text = 'ローリン♪ローリン♪ココロにズッキュン https://mstdn.example.com/1/2/3'
        assert_equal(@parser.length, 43)
      end

      def test_max_length
        assert(@parser.max_length.positive?)
        @parser.max_length = 5000
        assert_equal(@parser.max_length, 5000)
      end

      def test_to_md
        assert_kind_of(String, @parser.to_md)
      end

      def test_visibility_names
        assert_kind_of(Hash, TootParser.visibility_names)
      end

      def test_visibility_name
        ['public', 'unlisted', 'private', 'direct'].each do |key|
          assert_kind_of(String, TootParser.visibility_name(key))
        end
      end
    end
  end
end
