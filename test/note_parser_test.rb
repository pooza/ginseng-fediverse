module Ginseng
  module Fediverse
    class NoteParserTest < TestCase
      def setup
        @parser = NoteParser.new
      end

      def test_too_long?
        @parser.text = 'ローリン♪ローリン♪ココロにズッキュン'

        assert_false(@parser.too_long?)

        @parser.text = '0' * @parser.max_length

        assert_false(@parser.too_long?)

        @parser.text = '0' * (@parser.max_length + 1)

        assert_predicate(@parser, :too_long?)
      end

      def test_accts
        @parser.text = '@pooza @poozZa @pooza@mstdn.example.com pooza@b-shock.org'
        @parser.accts do |acct|
          assert_kind_of(Acct, acct)
          assert_predicate(acct, :valid?)
        end
        assert_equal(['@pooza', '@poozZa', '@pooza@mstdn.example.com'], @parser.accts.map(&:to_s))
      end

      def test_uris
        @parser.text = 'https://www.google.co.jp https://mstdn.b-shock.co.jp'
        @parser.uris do |uri|
          assert_kind_of(Ginseng::URI, uri)
          assert_predicate(uri, :absolute?)
        end
        assert_equal(['https://www.google.co.jp', 'https://mstdn.b-shock.co.jp'], @parser.uris.map(&:to_s))
      end

      def test_nokogiri
        assert_kind_of(
          [Nokogiri::HTML4::Document, Nokogiri::HTML5::Document, Nokogiri::XML::Document],
          @parser.nokogiri,
        )
      end

      def test_length
        @parser.text = 'ローリン♪ローリン♪ココロにズッキュン'

        assert_equal(19, @parser.length)

        @parser.text = '@admin ローリン♪ローリン♪ココロにズッキュン'

        assert_equal(26, @parser.length)

        @parser.text = '@admin@mstdn.example.com ローリン♪ローリン♪ココロにズッキュン'

        assert_equal(26, @parser.length)

        @parser.text = 'ローリン♪ローリン♪ココロにズッキュン https://mstdn.example.com'

        assert_equal(43, @parser.length)

        @parser.text = 'ローリン♪ローリン♪ココロにズッキュン https://mstdn.example.com/1/2/3'

        assert_equal(43, @parser.length)
      end

      def test_max_length
        assert_predicate(@parser.max_length, :positive?)
        @parser.max_length = 5000

        assert_equal(5000, @parser.max_length)
      end

      def test_to_md
        assert_kind_of(String, @parser.to_md)
      end

      def test_visibility_names
        assert_kind_of(Hash, NoteParser.visibility_names)
      end

      def test_visibility_name
        [:public, :unlisted, :private, :direct, :home, :followers, :specified].each do |key|
          assert_kind_of(String, NoteParser.visibility_name(key))
        end
      end

      def test_visibility_icons
        assert_kind_of(Hash, NoteParser.visibility_icons)
      end

      def test_visibility_icon
        [:public, :unlisted, :private, :direct, :home, :followers, :specified].each do |key|
          assert_kind_of(String, NoteParser.visibility_icon(key))
        end
      end
    end
  end
end
