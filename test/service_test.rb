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

      # 🔴🔴 **mfm-js が URL と読まない範囲は除外しない (#298)。**除外すると中の `@` が
      # メンションとして残り、**通知が飛ぶ**（すべて実測 0.26.0）。
      def test_escape_sigils_urls_misskey_does_not_read
        # scheme は小文字だけ（mfm-js の `https?://` は大文字小文字を区別する）
        assert_equal('HTTPS://x/@ admin', Service.escape_sigils('HTTPS://x/@admin'))
        # `:https:` が絵文字コードになる。⚠ 「詳細:URL」は普通に書かれる形
        assert_equal('詳細:https://x/@ admin', Service.escape_sigils('詳細:https://x/@admin'))
        assert_equal('a:bhttps://x/@ admin', Service.escape_sigils('a:bhttps://x/@admin'))
        # 手前のメンション・タグが scheme まで食う
        assert_equal('@ https://x/@ admin', Service.escape_sigils('@https://x/@admin'))
        assert_equal('# タグ・https://x/@ admin', Service.escape_sigils('#タグ・https://x/@admin'))
        assert_equal('#0**http://@ admin', Service.escape_sigils('#0**http://@admin'))
        # 閉じない fn も `$[https` までテキストとして読み進める
        assert_equal('$[https://x/@ admin', Service.escape_sigils('$[https://x/@admin'))
        assert_equal('$[x.y=1,https://x/@ admin', Service.escape_sigils('$[x.y=1,https://x/@admin'))
        # 🔴 mfm-js のタグ名は NBSP・U+2028 を越える（止まるのは半角・全角空白、タブ、改行だけ）
        assert_equal("#12\u00A0https://x/@ admin", Service.escape_sigils("#12\u00A0https://x/@admin"))
        assert_equal("#12\u2028https://x/@ admin", Service.escape_sigils("#12\u2028https://x/@admin"))
        # 除外しなかった URL の末尾の `$` と次の `[` で fn が開く
        assert_equal(':https://x/$[https://y/@ admin', Service.escape_sigils(':https://x/$[https://y/@admin'))
        # ネストの上限（Misskey は 20）では URL の途中の `~~` で打ち消し線が閉じる
        assert_equal("#{'>' * 19}~~https://x/~~@ admin", Service.escape_sigils("#{'>' * 19}~~https://x/~~@admin"))
        # ⚠ 除外しなかった URL の中の `#` も、同じ連なりの後ろの URL を食う
        assert_equal('詳細:https://x/#0**あhttps://y/@ b', Service.escape_sigils('詳細:https://x/#0**あhttps://y/@b'))
      end

      # ⚠ 空白で区切られていれば、手前の `#` `@` `:` は URL を食わない。
      def test_escape_sigils_keeps_urls_after_a_space
        assert_equal('詳細: https://x/@admin', Service.escape_sigils('詳細: https://x/@admin'))
        assert_equal('# タグ https://x/@admin', Service.escape_sigils('#タグ https://x/@admin'))
        assert_equal('(https://x/@admin)', Service.escape_sigils('(https://x/@admin)'))
      end

      # 🔴 **Ruby の `/i` は `ſ`（U+017F）を英字として扱う (#298)。**mfm-js（u フラグなし）は
      # 扱わないので、`ſ@admin` はメンションになる。
      def test_escape_sigils_long_s
        assert_equal('ſ@ admin', Service.escape_sigils('ſ@admin'))
        assert_equal('https://xſ/@ admin', Service.escape_sigils('https://xſ/@admin'))
      end

      # 🔴 **ホスト部に見える `@` も区切る (#298)。**`@admin_@adminp` を 1 つとして食い、
      # 先頭だけ区切ると `_@adminp` がメンションとして残る。
      def test_escape_sigils_acct_host_part
        assert_equal('@ admin_@ adminp', Service.escape_sigils('@admin_@adminp'))
        assert_equal('@ aſ@ b', Service.escape_sigils('@aſ@b'))
      end
    end
  end
end
