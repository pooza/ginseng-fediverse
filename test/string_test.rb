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
        assert_equal('search／# サーチ2', 'search／#サーチ2'.escape_toot)
        assert_equal('♪ # キボウレインボウ#', '♪ #キボウレインボウ#'.escape_toot)
        assert_equal("1 行目\n# タグ", "1 行目\n#タグ".escape_toot)
        assert_equal('@ pooza', '@pooza'.escape_toot)
        assert_equal('@ pooza@example.com', '@pooza@example.com'.escape_toot)
      end

      # 🔴 **リンク化しない `#` / `@` は触らない**（#273）。
      # ⚠⚠ **以前は無条件に全部置換していたので、ここは全部壊れていた** —
      # `IDOLM@STER` は上流のテストが `IDOLM@ STER` を期待値にしていた。
      def test_escape_toot_leaves_unlinkified
        assert_equal('IDOLM@STER', 'IDOLM@STER'.escape_toot)
        assert_equal('H@ppy Together!!!', 'H@ppy Together!!!'.escape_toot)
        assert_equal('foo@example.com', 'foo@example.com'.escape_toot)
        assert_equal('a#b', 'a#b'.escape_toot)
        assert_equal('https://example.com/#anchor', 'https://example.com/#anchor'.escape_toot)
      end

      # ⚠ **全角 `＃` も打ち消す (#275)。** 🔴 Mastodon は v4.5.0 (#36103) から
      # `[#＃]` で同じようにリンク化するので、拾わないのは実在の穴だった。
      # ⚠⚠ **印は全角のまま残す** — 半角へ寄せると本文を書き換えることになる。
      def test_escape_toot_fullwidth_sigil
        assert_equal('＃ 全角タグ', '＃全角タグ'.escape_toot)
        assert_equal('♪ ＃ 全角タグ', '♪ ＃全角タグ'.escape_toot)
      end

      # 🔴🔴 **全角 `＃` の境界は広げない (#275 Codex P2)。**
      #
      # ⚠⚠ **広げても守る相手がいない** — 実測で `あ＃タグ` `（＃タグ` は
      # **Mastodon（行頭か空白の直後を要求）も Misskey（`＃` をそもそも見ない）もタグにしない**。
      # 🔴 それを置換するのは、#273 で `H@ppy Together!!!` を `H@ ppy` にしていたのと同じ失敗。
      def test_escape_toot_does_not_widen_the_fullwidth_sigil
        assert_equal('あ＃タグ', 'あ＃タグ'.escape_toot)
        assert_equal('（＃タグ', '（＃タグ'.escape_toot)
      end

      # 🔴🔴 **無毒化の境界を Mastodon へ揃えないこと (#275)。**
      #
      # ⚠⚠ **相手は Mastodon だけではない。** 実測（mfm-js 0.26.0）: Misskey は直前が
      # ASCII 英数でなければタグにするので、下の 3 つは**投稿先でリンク化される**
      # （🔴 Mastodon は `(?<=^|[[:space:]])` なのでどれもタグにしない）。
      # ⚠ 抽出の境界と共有させると、ここの保護が黙って外れる。
      def test_escape_toot_covers_what_misskey_linkifies
        assert_equal('search／# サーチ2', 'search／#サーチ2'.escape_toot)
        assert_equal('あ# タグ', 'あ#タグ'.escape_toot)
        assert_equal('## tag', '##tag'.escape_toot)
      end

      # ⚠ **数字だけのタグは触らない (#275)。** 🔴 **拾わなくて正しい** —
      # Mastodon は `[[:alpha:]]` を 1 文字要求し、mfm-js は数字のみを弾く。
      def test_escape_toot_leaves_numeric_tag
        assert_equal('#123', '#123'.escape_toot)
        assert_equal('＃123', '＃123'.escape_toot)
      end

      # 🔴🔴 **中黒 `・` は区切りに入れない（Mastodon と意図してずらす・#275）。**
      # ⚠⚠ 入れると `TagContainer` の生成側が回り、`#プリキュア_オールスターズ` という
      # **別のタグが生える**。⚠ この期待値が例外を守っている。
      def test_escape_toot_stops_at_middle_dot
        assert_equal('# プリキュア・オールスターズ', '#プリキュア・オールスターズ'.escape_toot)
      end
    end
  end
end
