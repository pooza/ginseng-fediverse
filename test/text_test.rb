module Ginseng
  module Fediverse
    class TextTest < TestCase
      # ⚠ 中身は `TagContainer` から**移しただけ (#277)**。振る舞いの検算は
      # `tag_container_test.rb` 側にもあるので、ここでは**新しい置き場所**と、
      # **移したときに足した `entry` (#263)** を固定する。
      def test_utf8_is_returned_as_is
        assert_equal('ほげ', Text.to_utf8('ほげ'))
        assert_equal(Encoding::UTF_8, Text.to_utf8('ほげ').encoding)
      end

      # ⚠⚠ **ASCII-8BIT は「符号化が不明」というラベルであって符号化ではない。**
      # 🔴 中身が妥当な UTF-8 なら、**ラベルを剥がすだけで 1 バイトも動かさない**。
      def test_a_binary_label_is_removed_when_the_bytes_are_valid
        assert_equal('ほげ', Text.to_utf8('ほげ'.b))
        assert_equal('ほげ'.bytes, Text.to_utf8('ほげ'.b).bytes, '中身を変えていないこと')
        assert_equal(Encoding::UTF_8, Text.to_utf8('ほげ'.b).encoding)
      end

      # ⚠ **寄せられるものは寄せる。**
      def test_other_encodings_are_converted
        assert_equal('ほげ', Text.to_utf8('ほげ'.encode('Windows-31J')))
      end

      # ⚠⚠ **寄せられないものは弾いて呼び側に返す。** 🔴 `scrub` で黙って直さない
      # （"\xE3\x81ほげ" が "�ほげ" になり、**化けたタグが投稿される**）。
      def test_what_cannot_be_converted_is_rejected
        assert_raise(ValidateError) {Text.to_utf8("abc\xFF".b)}
        assert_raise(ValidateError) {Text.to_utf8("\xE3\x81ほげ")}
      end

      # ⚠ **妥当でない BINARY は触らない**（`relabel_binary` の側の契約）。
      def test_an_invalid_binary_keeps_its_label
        string = "abc\xFF".b

        assert_equal(Encoding::BINARY, Text.relabel_binary(string).encoding)
        assert_equal(string.bytes, Text.relabel_binary(string).bytes)
      end

      # 🔴 **どの入口で弾かれたかを残す (#263)。** ⚠ 入口が 6 通りあるので、
      # これが無いと**利用側のログだけでは backtrace を読むまで切り分けられない**。
      def test_the_entry_is_written_into_the_message
        error = assert_raise(ValidateError) {Text.to_utf8("abc\xFF".b, 'Widget#draw')}
        assert_include(error.message, 'Widget#draw')

        error = assert_raise(ValidateError) {Text.to_utf8("\xE3\x81ほげ", 'Widget#draw')}
        assert_include(error.message, 'Widget#draw')
      end

      # ⚠ **後ろに添える。** 🔴 前に付けると、メッセージの頭で振り分けている
      # 利用側を壊す。
      def test_the_entry_is_appended_not_prepended
        error = assert_raise(ValidateError) {Text.to_utf8("\xE3\x81ほげ", 'Widget#draw')}
        assert_true(error.message.start_with?('invalid byte sequence in UTF-8'))
      end

      # ⚠ 省略できること（委譲のため）。
      def test_the_entry_is_optional
        error = assert_raise(ValidateError) {Text.to_utf8("\xE3\x81ほげ")}
        assert_equal('invalid byte sequence in UTF-8', error.message)
      end

      # 🔴🔴 **`v2.0.0` で公開した口を壊さない (#277)。** ⚠⚠ 利用側は
      # `TagContainer.to_utf8` を**唯一の汎用の口**として呼んでいるので、
      # 移しただけで消すと落ちる。
      def test_the_old_name_still_works
        assert_equal('ほげ', TagContainer.to_utf8('ほげ'.b))
        assert_raise(ValidateError) {TagContainer.to_utf8("abc\xFF".b)}
        assert_equal(Encoding::BINARY, TagContainer.relabel_binary("abc\xFF".b).encoding)
      end
    end
  end
end
