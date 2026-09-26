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

      # 🔴🔴 **BINARY のラベルが付いた本文が、黙って化けていた (#276)。**
      #
      # ⚠⚠ **`#276` は「本番の口は無事」と書いていたが、成り立っていなかった** —
      # 例外にならず、`sanitize!` の中の Nokogiri で**1 文字ずつ置換文字に潰れる**。
      # 🔴 実測（`v3.0.0`）: `"ほげ #tag @pooza".b` → `"������ # tag @ pooza"`。
      # ⚠ **Sequel / SQLite が非 ASCII をこの形で返す**ので、利用側は素直に踏む。
      def test_sanitize_status_keeps_a_binary_labelled_body
        assert_equal('ほげ # tag @ pooza', Service.sanitize_status('ほげ #tag @pooza'.b))
      end

      # ⚠⚠ **本番の投稿の口なので、妥当でないバイト列でも例外にしない。**
      # 🔴 ここで上げると**その枠が 1 通も投稿されなくなる** — `#277` が困っている
      # ことそのものを、こちらが作ることになる。⚠ `v3.0.0` と同じ結果であること。
      def test_sanitize_status_does_not_start_rejecting_what_it_used_to_pass
        assert_equal("abc\uFFFD # tag", Service.sanitize_status("abc\xFF #tag".b))
        assert_equal('ほげ # tag', Service.sanitize_status('ほげ #tag'.encode('Windows-31J')))
      end

      # 🔴🔴 **入口を緩めないこと（リリース前レビュー）。** ⚠⚠ `to_s` で受けると
      # `nil` が `""` に化けて、**本文が無いのに空の投稿が出る**。`v3.0.0` と同じく
      # 落ちること。
      def test_sanitize_status_still_refuses_what_is_not_a_string
        [nil, 123, :sym].each do |value|
          assert_raise(NoMethodError) {Service.sanitize_status(value)}
        end
      end

      # 🔴🔴 **BINARY 以外のラベルを踏み潰さないこと（リリース前レビュー）。**
      # ⚠⚠ `Text.relabel_binary` には BINARY かどうかの検査が無いので、素の文字列に
      # 直に当てると **`force_encoding` で他の符号化のラベルが消える** — バイト列が
      # たまたま妥当な UTF-8 になるものが化ける。
      def test_sanitize_status_does_not_stamp_utf8_on_another_encoding
        # ⚠ ISO-8859-1 の "Ã©" は**バイト列としては妥当な UTF-8**（U+00E9）なので、
        # 検査が抜けると「é」に化ける。
        text = "\xC3\xA9".dup.force_encoding(Encoding::ISO_8859_1)

        assert_equal(Encoding::ISO_8859_1, text.encoding, '前提')
        assert_true(text.dup.force_encoding(Encoding::UTF_8).valid_encoding?, '前提')
        assert_equal('Ã©', Service.sanitize_status(text))
      end

      # 🔴 **`escape_sigils` を直接呼ぶ経路だけが落ちていた (#276)。**
      # ⚠ `hashtag_sigil_pattern` は `·`（U+00B7）を含む UTF-8 の正規表現なので、
      # ASCII-8BIT の文字列に当てると `Encoding::CompatibilityError` になっていた。
      def test_escape_sigils_takes_a_binary_labelled_string
        assert_equal('ほげ # tag', Service.escape_sigils('ほげ #tag'.b))
      end

      # ⚠⚠ **こちらは公開した API の口なので、寄せられないものは弾く (#248 と同じ方針)。**
      # 🔴 どの入口かも残す (#263)。
      def test_escape_sigils_rejects_what_it_cannot_convert
        error = assert_raise(ValidateError) {Service.escape_sigils("abc\xFF".b)}
        assert_include(error.message, 'Service.escape_sigils')
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

      # 🔴🔴 **`@` の境界が抽出用のままで、Misskey がメンションにする形を素通りしていた。**
      # ⚠⚠ mfm-js は**直前が ASCII 英数のときだけ**メンションにしない（実測 0.26.0）ので、
      # 和文字・`_` の直後の `@` も通知が飛ぶ。⚠ 曲名・アーティスト名は第三者が付ける。
      def test_escape_sigils_acct_on_misskey_boundary
        assert_equal('ラブ@ pooza', Service.escape_sigils('ラブ@pooza'))
        assert_equal('_@ admin', Service.escape_sigils('_@admin'))
        assert_equal('曲「@ admin」', Service.escape_sigils('曲「@admin」'))
        assert_equal('ラブ@ pooza@misskey.io', Service.escape_sigils('ラブ@pooza@misskey.io'))
        assert_equal('x.@ pooza', Service.escape_sigils('x.@pooza'))
      end

      # ⚠ **広げすぎない。**どこもメンションにしない形は壊さない（#273 の `H@ppy` と同じ失敗）。
      def test_escape_sigils_acct_keeps_what_nobody_links
        assert_equal('H@ppy Together!!!', Service.escape_sigils('H@ppy Together!!!'))
        assert_equal('info@example.com', Service.escape_sigils('info@example.com'))
        assert_equal('ラブ＠pooza', Service.escape_sigils('ラブ＠pooza'))
        assert_equal('https://mstdn.example.com/@pooza', Service.escape_sigils('https://mstdn.example.com/@pooza'))
      end

      # 🔴 **URL の途中は区切らない（#290 Codex P2）。**境界を広げたぶん、`_@` `_#` が
      # URL の中で当たるようになった。⚠ mfm-js は URL を丸ごと食うので守る相手がいない。
      def test_escape_sigils_keeps_urls
        assert_equal('https://example.com/_@admin', Service.escape_sigils('https://example.com/_@admin'))
        assert_equal('https://example.com/_#frag', Service.escape_sigils('https://example.com/_#frag'))
        assert_equal('ラブ@ pooza https://example.com/_@admin', Service.escape_sigils('ラブ@pooza https://example.com/_@admin'))
        assert_equal('https://example.com/"@ admin', Service.escape_sigils('https://example.com/"@admin'))
        assert_equal('# a https://example.com/_#b # c', Service.escape_sigils('#a https://example.com/_#b #c'))
      end
    end
  end
end
