module Ginseng
  module Fediverse
    class StringTest < TestCase
      def test_to_hashtag
        assert_equal('宮本佳那子'.to_hashtag, '#宮本佳那子')
        assert_equal('宮本 佳那子'.to_hashtag, '#宮本_佳那子')
        assert_equal('宮本 佳那子 '.to_hashtag, '#宮本_佳那子')
        assert_equal('#宮本 佳那子 '.to_hashtag, '#宮本_佳那子')
      end

      def test_to_hashtag_base
        assert_equal('宮本佳那子'.to_hashtag_base, '宮本佳那子')
        assert_equal('宮本 佳那子'.to_hashtag_base, '宮本_佳那子')
        assert_equal('宮本 佳那子 '.to_hashtag_base, '宮本_佳那子')
        assert_equal('#宮本 佳那子 '.to_hashtag_base, '宮本_佳那子')
      end
    end
  end
end
