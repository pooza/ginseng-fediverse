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

      def test_sanitize_status
        assert_equal('宮本佳那子', Service.sanitize_status('<p>宮本佳那子</p>'))
        assert_equal("宮本佳那子\n宮本佳那子", Service.sanitize_status('宮本佳那子<br>宮本佳那子'))
        assert_equal("宮本佳那子\n宮本佳那子", Service.sanitize_status('宮本佳那子<br/>宮本佳那子<br>'))
        assert_equal("宮本佳那子\n宮本佳那子", Service.sanitize_status('宮本佳那子<br />宮本佳那子 '))
      end

      # ⚠ **HTML の除去と区切りの挿入が同じ口で起きる**（#273）。
      def test_sanitize_status_escapes_sigils
        assert_equal('# キボウレインボウ#', Service.sanitize_status('<p>#キボウレインボウ#</p>'))
        assert_equal('IDOLM@STER', Service.sanitize_status('<p>IDOLM@STER</p>'))
        assert_equal("♪ # キボウレインボウ#\n@ pooza", Service.sanitize_status('♪ #キボウレインボウ#<br>@pooza'))
      end

      def test_escape_sigils
        assert_equal('# キボウレインボウ#', Service.escape_sigils('#キボウレインボウ#'))
        assert_equal('IDOLM@STER', Service.escape_sigils('IDOLM@STER'))
        assert_equal('# a # b', Service.escape_sigils('#a #b'))
        assert_equal('## tag', Service.escape_sigils('##tag'))
        assert_equal('', Service.escape_sigils(''))
      end
    end
  end
end
