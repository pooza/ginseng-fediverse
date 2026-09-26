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

      # 🔴🔴 **`@` の境界が抽出用のままで、Misskey がメンションにする形を素通りしていた**（#291）。
      def test_escape_sigils_acct_on_misskey_boundary
        assert_equal('ラブ@ pooza', Service.escape_sigils('ラブ@pooza'))
        assert_equal('_@ admin', Service.escape_sigils('_@admin'))
        assert_equal('曲「@ admin」', Service.escape_sigils('曲「@admin」'))
        assert_equal('ラブ@ pooza@misskey.io', Service.escape_sigils('ラブ@pooza@misskey.io'))
        assert_equal('x.@ pooza', Service.escape_sigils('x.@pooza'))
        assert_equal('曲/@ admin', Service.escape_sigils('曲/@admin'))
        assert_equal('a/@ admin', Service.escape_sigils('a/@admin'))
      end

      # ⚠ **広げすぎない。**どこもメンションにしない形は壊さない。
      def test_escape_sigils_acct_keeps_what_nobody_links
        assert_equal('H@ppy Together!!!', Service.escape_sigils('H@ppy Together!!!'))
        assert_equal('info@example.com', Service.escape_sigils('info@example.com'))
        assert_equal('ラブ＠pooza', Service.escape_sigils('ラブ＠pooza'))
        assert_equal('https://mstdn.example.com/@pooza', Service.escape_sigils('https://mstdn.example.com/@pooza'))
      end

      # 🔴 **URL の途中は区切らない**（#291）。⚠ 2.0.1 は `?a=#frag` を `?a=# frag` に壊していた。
      def test_escape_sigils_keeps_urls
        assert_equal('https://example.com/_@admin', Service.escape_sigils('https://example.com/_@admin'))
        assert_equal('https://example.com/?a=#frag', Service.escape_sigils('https://example.com/?a=#frag'))
        assert_equal('ラブ@ pooza https://example.com/_@admin', Service.escape_sigils('ラブ@pooza https://example.com/_@admin'))
        assert_equal('# a https://example.com/?a=#b # c', Service.escape_sigils('#a https://example.com/?a=#b #c'))
      end
    end
  end
end
