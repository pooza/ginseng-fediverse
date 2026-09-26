module Ginseng
  module Fediverse
    # ⚠ 利用側が派生させている（`pooza/mulukhiya-toot-proxy`）ので、
    # **基底の名前だけ出る形になっていないか**を測るための派生。
    class DerivedContainer < TagContainer; end

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

      # ⚠⚠ **抽出の境界は Mastodon 完全互換 (#275)。** 🔴 無毒化と違ってこちらは
      # 「正確」側 — 行頭か空白の直後だけをタグとして数える。
      def test_scan_uses_the_mastodon_boundary
        assert_equal(Set['全角タグ'], TagContainer.scan('＃全角タグ'))
        assert_equal(Set['タグ'], TagContainer.scan("1 行目\n#タグ"))
        assert_equal(Set[], TagContainer.scan('あ#タグ'), '直前が空白でなければタグではない')
        assert_equal(Set[], TagContainer.scan('search／#サーチ2'))
        assert_equal(Set[], TagContainer.scan('#123'), '数字だけはタグではない')
      end

      # 🔴🔴 **中黒 `・` は区切りに入れない（Mastodon と意図してずらす・#275）。**
      # ⚠ 長年タグにならず、その前提で運用されているため。
      def test_scan_stops_at_middle_dot
        assert_equal(Set['プリキュア'], TagContainer.scan('#プリキュア・オールスターズ'))
      end

      # ⚠ **区切り文字は Mastodon の写し (#275)。** U+00B7（ラテンの中点）と
      # U+200C（ZWNJ）はタグ名の途中に入れる。
      def test_scan_allows_mastodon_separators
        assert_equal(Set["l\u00B7l\u00B7l"], TagContainer.scan("#l\u00B7l\u00B7l"))
        # ⚠⚠ **ZWNJ は目で見えないので必ずエスケープで書く。**
        assert_equal(Set["a\u200Cb"], TagContainer.scan("#a\u200Cb"))
      end

      # 🔴 **本文の全角 `＃` を見落とさない (#275)。** ⚠⚠ 見落とすと、本文に
      # 既にあるタグを**末尾にもう一度足す**。
      #
      # ⚠⚠ **守っているのは `create_pattern` の印ではなく、`text=` の NFKC 正規化。**
      # 🔴 実測で確かめた — `＃` は `@text` に入る時点で `#` になるので、
      # `create_pattern` を半角決め打ちのままにしてもここは通る。⚠ **正規化を外した日に
      # 黙って壊れるので、仕様の側をここで固定しておく。**
      def test_create_tags_sees_a_fullwidth_sigil_in_the_text
        @container.push('タグ')
        @container.text = '＃タグ を見た'

        assert_equal(Set[], @container.create_tags, '本文にあるタグを足さないこと')
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

      # 🔴 **空白や記号を含む値は、どの形で引いても当たらなかった (#260)。**
      # 設定や辞書から入る値（mulukhiya の image_copyright / remote_tag）の形。
      def test_member_raw_forms
        container = TagContainer.new(['剣崎 真琴', 'ドキドキ!プリキュア', 'foo'])
        queries = ['剣崎 真琴', '剣崎真琴', '#剣崎真琴', 'ドキドキ!プリキュア', 'ドキドキ_プリキュア', '#foo']
        queries.each do |query|
          member = container.member?(query)

          assert_true(member, query)
        end
      end

      # 🔴 **Mastodon は `tags[].name` を正規化して返す (#260)。** mulukhiya は投稿の応答を
      # `member?` で絞っていたので、大文字や `·` / ZWNJ を含むタグが応答から消えていた。
      def test_member_mastodon_names
        {'#FooBar' => 'foobar', "#l\u00B7l\u00B7l" => "l\u00B7l\u00B7l", "#a\u200Cb" => "a\u200Cb",
         '#ＦＯＯ' => 'foo'}.each do |text, name|
          member = TagContainer.scan(text).member?(name)

          assert_true(member, text)
        end
      end

      # 🔴 **NFKC が畳み方の消す文字を生む場合（Codex P2）。** `Ŀ` は `l·` に、`क़` は
      # `क` ＋ヌクタに分かれ、投稿先はどちらも消した名前を返す。
      def test_member_characters_introduced_by_nfkc
        {"\u013F" => ["l\u00B7", 'l'], "\u0958" => ["\u0915", "\u0915\u093C", "\u0958"]}.each do |stored, names|
          container = TagContainer.new([stored])
          names.each do |name|
            member = container.member?(name)

            assert_true(member, "#{stored} / #{name}")
          end
        end
      end

      # ⚠ **出力されるタグと `member?` の答えが揃っていること**（畳み方の共通化）。
      def test_member_matches_create_tags
        container = TagContainer.new(['剣崎 真琴', 'Go!プリンセスプリキュア', 'foo bar', 'ＦＯＯ bar'])
        container.create_tags.each do |tag|
          member = container.member?(tag)

          assert_true(member, tag)
        end
      end

      def test_member_rejects
        container = TagContainer.new(['foo', '!!!'])
        ['bar', '', '#', '!!!', 'foo_bar'].each do |query|
          member = container.member?(query)

          assert_false(member, query)
        end
      end

      # ⚠ **`include?` は `Set` のまま**（格納値との完全一致）。変えるなら major (#260)。
      def test_include_stays_exact
        container = TagContainer.new(['剣崎 真琴'])

        assert_false(container.include?('剣崎真琴'))
        assert_true(container.include?('剣崎 真琴'))
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

      # 🔴 **どの入口で弾かれたかが分かること (#263)。** ⚠⚠ 入口が 6 通りあるので、
      # 例外メッセージにこれが無いと**タグを push して落ちたのか、本文を text= して
      # 落ちたのか、突き合わせに落ちたのか**が利用側のログからは分からない。
      def test_each_entry_names_itself
        entries = {
          'TagContainer#add' => -> {@container.add(invalid_utf8)},
          'TagContainer#member?' => -> {@container.member?(invalid_utf8)},
          'TagContainer#delete' => -> {@container.delete(invalid_utf8)},
          'TagContainer#text=' => -> {@container.text = invalid_utf8},
          'TagContainer.scan' => -> {TagContainer.scan(invalid_utf8)},
        }
        entries.each do |label, entry|
          error = assert_raise(ValidateError, &entry)
          assert_include(error.message, label)
        end
      end

      # ⚠⚠ **別名は元の名前に畳まれる。** `push` は `#add`、`body=` は `#text=`。
      # 🔴 切り分けたいのは「どの経路を通ったか」なので、これで足りる。
      def test_an_alias_reports_the_defined_name
        error = assert_raise(ValidateError) {@container.push(invalid_utf8)}
        assert_include(error.message, 'TagContainer#add')
      end

      # ⚠ **サブクラスは自分の名前を出す。** 利用側が派生させている
      # （`pooza/mulukhiya-toot-proxy`）ので、基底の名前だけだと辿れない。
      def test_a_subclass_names_itself
        error = assert_raise(ValidateError) {DerivedContainer.new.add(invalid_utf8)}
        assert_include(error.message, 'DerivedContainer#add')
      end

      # ⚠ 正常系を壊していないこと。UTF-8 はそのまま通る。
      def test_utf8_is_untouched
        assert_equal('ほげ', TagContainer.to_utf8('ほげ'))
        assert_equal(Encoding::UTF_8, TagContainer.to_utf8('ほげ').encoding)
      end
    end
  end
end
