module Ginseng
  module Fediverse
    class StringTest < TestCase
      def test_to_hashtag
        assert_equal('#宮本佳那子', '宮本佳那子'.to_hashtag)
        assert_equal('#宮本_佳那子', '宮本 佳那子'.to_hashtag)
        assert_equal('#宮本_佳那子', '宮本 佳那子 '.to_hashtag)
        assert_equal('#宮本_佳那子', '#宮本 佳那子 '.to_hashtag)
      end

      def test_to_hashtag_base
        assert_equal('宮本佳那子', '宮本佳那子'.to_hashtag_base)
        assert_equal('宮本_佳那子', '宮本 佳那子'.to_hashtag_base)
        assert_equal('宮本_佳那子', '宮本 佳那子 '.to_hashtag_base)
        assert_equal('宮本_佳那子', '#宮本 佳那子 '.to_hashtag_base)
      end

      def test_escape_toot
        assert_equal('# キボウレインボウ#', '#キボウレインボウ#'.escape_toot)
        assert_equal('IDOLM@ STER', 'IDOLM@STER'.escape_toot)
        assert_equal('search／# サーチ2', 'search／#サーチ2'.escape_toot)
      end
    end
  end
end
