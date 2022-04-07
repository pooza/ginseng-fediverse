module Ginseng
  module Fediverse
    class ServiceTest < TestCase
      def test_create_tag
        assert_equal('#宮本佳那子', Service.create_tag('宮本佳那子'))
        assert_equal('#宮本_佳那子', Service.create_tag('宮本 佳那子'))
        assert_equal('#宮本_佳那子', Service.create_tag('宮本 佳那子 '))
        assert_equal('#宮本_佳那子', Service.create_tag('#宮本 佳那子 '))
      end

      def test_create_tag_base
        assert_equal('宮本佳那子', Service.create_tag_base('宮本佳那子'))
        assert_equal('宮本_佳那子', Service.create_tag_base('宮本 佳那子'))
        assert_equal('宮本_佳那子', Service.create_tag_base('宮本 佳那子 '))
        assert_equal('宮本_佳那子', Service.create_tag_base('#宮本 佳那子 '))
      end
    end
  end
end
