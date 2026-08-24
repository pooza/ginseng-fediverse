module Ginseng
  module Fediverse
    class TagContainerTest < TestCase
      def setup
        @container = TagContainer.new
      end

      def test_push
        assert_equal(@container.push(111), Set['111'])
      end

      def test_create_tags
        @container.push('カレー担々麺')
        @container.push('コスモグミ')

        assert_equal(@container.create_tags, Set['#カレー担々麺', '#コスモグミ'])

        @container.push('剣崎 真琴')
        @container.push('Makoto Kenzaki')

        assert_equal(@container.create_tags, Set['#カレー担々麺', '#コスモグミ', '#剣崎真琴', '#Makoto_Kenzaki'])

        @container.clear
        @container.push('武田 信玄')

        assert_equal(@container.create_tags, Set['#武田信玄'])

        @container.clear
        @container.push('Yes!プリキュア5 GoGo!')

        assert_equal(@container.create_tags, Set['#Yes_プリキュア5GoGo'])

        @container.clear
        @container.push('よにんでSUPER TEUCHI STATION ONLINE')

        assert_equal(@container.create_tags, Set['#よにんでSUPER_TEUCHI_STATION_ONLINE'])
      end

      def test_push_blank
        @container.push('')
        @container.push(nil)
        @container.push('#')

        assert_equal(Set[], @container)
        assert_equal(Set[], @container.create_tags)
      end

      def test_new_with_blank
        container = TagContainer.new(['foo', '', nil, '#', 'bar'])

        assert_equal(Set['foo', 'bar'], container)
        assert_equal(Set['#foo', '#bar'], container.create_tags)
      end

      def test_scan
        assert_equal(TagContainer.scan('#フワ #プルンス'), Set['フワ', 'プルンス'])
      end

      def test_delete
        @container.push('実況')
        @container.push('precure_fun')

        assert_equal(@container.delete('実況'), @container)
        assert_equal(Set['precure_fun'], @container)
      end

      def test_delete_case_insensitive
        @container.push('Makoto')
        @container.push('precure_fun')

        assert_equal(@container.delete('MAKOTO'), @container)
        assert_equal(Set['precure_fun'], @container)
      end

      def test_delete_missing
        @container.push('precure_fun')

        assert_nil(@container.delete('実況'))
        assert_equal(Set['precure_fun'], @container)
      end

      def test_select_bang_with_short_tags
        @container.push('実況')
        @container.push('precure_fun')

        assert_nothing_raised do
          @container.select! {|v| v.to_s.length > 2}
        end
        assert_equal(Set['precure_fun'], @container)
      end

      # ⚠⚠ **エンコーディングの契約 (#248)。**
      #
      # このクラスは押し込まれた文字列が UTF-8 であることを決め打ちしていたが
      # 検査しておらず、入口ごとに 4 通りに挙動が割れていた。⚠ **黙って中身が
      # 消える経路があるのが本質的な問題**で、例外になる経路より質が悪い。
      #
      # ⚠ `scrub` で直す案は採らない。`"\xE3\x81ほげ"` が `"�ほげ"` になり、
      # **化けたタグがそのまま投稿される**。

      def invalid_utf8
        return "\xE3\x81ほげ".dup.force_encoding(Encoding::UTF_8)
      end

      def sjis
        return 'ほげ'.encode('Windows-31J')
      end

      # 🔴 **本丸。**Shift_JIS を押し込むと `"#"` になって**中身だけが消えていた**。
      def test_push_shift_jis
        @container.push(sjis)

        assert_equal(Set['ほげ'], @container)
        assert_equal('#ほげ', @container.to_s)
      end

      # ⚠ 寄せた結果は UTF-8 になっていること（元の encoding を引きずらない）。
      def test_push_shift_jis_is_utf8
        @container.push(sjis)

        assert_equal(Encoding::UTF_8, @container.first.encoding)
      end

      # ⚠ ASCII の範囲なら ASCII-8BIT でも通る。
      def test_push_binary_ascii
        @container.push('precure'.b)

        assert_equal(Set['precure'], @container)
      end

      # ⚠ **中身が妥当な UTF-8 なら、ASCII-8BIT でも通ること。**
      #
      # ⚠⚠ **ASCII-8BIT は符号化ではなくラベルなので、`encode` に掛けると非 ASCII が
      # 必ず UndefinedConversionError になる。**⚠ Sequel / SQLite が非 ASCII をこの形で
      # 返すので、利用側は素直に踏む（pooza/makoto2#171）。
      def test_push_binary_utf8
        @container.push('ほげ'.b)

        assert_equal(Set['ほげ'], @container)
        assert_equal(Encoding::UTF_8, @container.first.encoding)
      end

      def test_text_binary_utf8
        @container.text = 'ほげ です'.b

        assert_equal('ほげ です', @container.text)
      end

      # ⚠⚠ **寄せられないものは弾く。**黙って落とさない。
      def test_push_undecodable_binary
        assert_raise(ValidateError) do
          @container.push("abc\xFF".b)
        end
      end

      # ⚠ 不正バイト列は ArgumentError ではなく ValidateError で返す
      # （`Ginseng::Error` の系で捕まえられるようにする）。
      def test_push_invalid_utf8
        assert_raise(ValidateError) do
          @container.push(invalid_utf8)
        end
      end

      def test_scan_invalid_utf8
        assert_raise(ValidateError) do
          TagContainer.scan(invalid_utf8)
        end
      end

      def test_scan_shift_jis
        assert_equal('#ほげ', TagContainer.scan('#ほげ です'.encode('Windows-31J')).to_s)
      end

      # 🔴 **黙って false になっていた。**
      #
      # ⚠ `assert_includes` を使わない。`TagContainer` が上書きしているのは
      # `member?` **だけ**で、`Set#include?` / `#===` は素のままなので、
      # `assert_includes` では**この上書きを通らない**（#260）。
      def test_member_shift_jis
        @container.push('ほげ')

        # ⚠ 直に書くと Minitest/AssertIncludes と Minitest/AssertTruthy が
        #   互いに反対を要求して収まらない。局所変数に受けて外す。
        member = @container.member?(sjis)

        assert(member)
      end

      # 🔴 `casecmp` が nil を返し、`.zero?` が NoMethodError になっていた。
      def test_delete_shift_jis
        @container.push('ほげ')
        @container.delete(sjis)

        assert_empty(@container)
      end

      def test_text_shift_jis
        @container.text = sjis

        assert_equal('ほげ', @container.text)
      end

      def test_text_invalid_utf8
        assert_raise(ValidateError) do
          @container.text = invalid_utf8
        end
      end

      # ⚠ 正常系を壊していないこと。UTF-8 はそのまま通る。
      def test_utf8_is_untouched
        assert_equal('ほげ', TagContainer.to_utf8('ほげ'))
        assert_equal(Encoding::UTF_8, TagContainer.to_utf8('ほげ').encoding)
      end
    end
  end
end
