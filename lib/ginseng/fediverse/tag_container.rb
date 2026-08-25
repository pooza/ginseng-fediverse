module Ginseng
  module Fediverse
    class TagContainer < Set
      include Package

      attr_reader :text

      def add(word)
        normalized = normalize(self.class.to_utf8(word))
        return self if normalized.empty?
        @tags = nil
        return super(normalized)
      end

      alias push add

      def member?(tag)
        return super(self.class.to_utf8(tag).to_hashtag_base)
      end

      def merge(words)
        words.each {|v| add(v)}
      end

      alias concat merge

      def normalize(word)
        return word.sub(/^#/, '')
      end

      alias body text

      # ⚠ `casecmp` はエンコーディングが噛み合わないと **nil を返す**ので、
      # 検査を挟まないと `.zero?` が `NoMethodError` になる（#248）。
      def delete(tag)
        tag = self.class.to_utf8(tag)
        matches = filter {|v| v.casecmp(tag).zero?}
        return nil if matches.empty?
        matches.each {|v| super(v)}
        @tags = nil
        return self
      end

      def text=(text)
        @tags = nil
        @text = self.class.to_utf8(text).nfkc
      end

      alias body= text=

      def count
        return create_tags.count
      end

      def to_s
        return create_tags.join(' ')
      end

      def create_tags
        @tags ||= map {|tag| tag.gsub(/([a-z0-9]{2,})[[:blank:]]/i, '\\1_')}
          .filter_map {|tag| tag.gsub(/[[:blank:]]/, '').presence}
          .map(&:to_hashtag)
          .reject {|tag| @text&.match?(create_pattern(tag))}
          .to_set
        return @tags
      end

      def self.scan(text)
        return new(
          # ⚠ `scan` 自体が不正バイト列で `ArgumentError` を上げるので、
          #   `add` へ届く前にここで検査する（#248）。
          to_utf8(text).scan(Parser.hashtag_pattern).map(&:first),
        )
      end

      # ⚠⚠ **入口で UTF-8 を保証する (#248)。** このクラスは押し込まれた文字列が
      # UTF-8 であることを決め打ちしていたが検査しておらず、入口ごとに
      # **4 通りに挙動が割れていた**。
      #
      #   add / scan  不正バイト列 → ArgumentError（型が不明瞭で捕まえにくい）
      #   add         Shift_JIS    → 🔴 **黙って中身が消える**（"#" になる）
      #   member?     Shift_JIS    → 🔴 **黙って false**
      #   delete      Shift_JIS    → casecmp が nil を返し NoMethodError
      #
      # ⚠ **UTF-8 に寄せられるものは寄せ**（Shift_JIS など）、**寄せられないものは
      # 弾いて呼び側に返す**。⚠⚠ **scrub で黙って直さないこと** —
      # "\xE3\x81ほげ" が "�ほげ" になり、**化けたタグが投稿される**。
      def self.to_utf8(value)
        string = value.to_s
        string = relabel_binary(string) if string.encoding == Encoding::BINARY
        unless string.encoding == Encoding::UTF_8
          begin
            string = string.encode(Encoding::UTF_8)
          rescue EncodingError => e
            raise ValidateError, "cannot convert to UTF-8 (#{string.encoding}): #{e.message}"
          end
        end
        raise ValidateError, 'invalid byte sequence in UTF-8' unless string.valid_encoding?
        return string
      end

      # ASCII-8BIT のラベルだけを剥がす。⚠ **中身が妥当な UTF-8 のときだけ。**
      #
      # ⚠⚠ **ASCII-8BIT は「符号化が不明」というラベルであって符号化ではない**ので、
      # `encode` の変換元にすると**非 ASCII は必ず UndefinedConversionError** になる。
      # 実際、`'ほげ'.b` は中身が妥当な UTF-8 なのに ValidateError で弾かれていた。
      #
      # ⚠ **Sequel / SQLite が非 ASCII をこの形で返す**ので、利用側では素直に踏む
      # （pooza/makoto2#171 で、本文のタグ付けが黙って落ちた）。
      #
      # ⚠ **妥当でなければ触らない。**`"abc\xFF".b` は従来どおり下の encode が弾く
      # （#248 の「寄せられないものは黙って落とさない」は変えていない）。
      def self.relabel_binary(string)
        relabeled = string.dup.force_encoding(Encoding::UTF_8)
        return relabeled.valid_encoding? ? relabeled : string
      end

      private

      def create_pattern(tag)
        return Regexp.new("#{tag.to_hashtag}([^[:word:]]|$)")
      end
    end
  end
end
