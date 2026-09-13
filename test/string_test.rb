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

      # ⚠ **拾えないものを期待値として固定しておく**（#273 の「残っている穴」）。
      # 🔴 **どちらも以前の無条件置換でも拾えていない**（`＃` は ASCII の `#` ではなく、
      # 数字だけのタグは `Parser.hashtag_pattern` が弾く）。⚠⚠ **広げた日にここが
      # 落ちるので、そのとき意図した変更かどうかが分かる。**
      def test_escape_toot_known_gaps
        assert_equal('＃全角タグ', '＃全角タグ'.escape_toot)
        assert_equal('#123', '#123'.escape_toot)
      end
    end
  end
end
