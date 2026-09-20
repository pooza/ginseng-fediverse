module Ginseng
  module Fediverse
    # ⚠⚠ **タグに紐づかない、本文そのものの前処理 (#277)。**
    #
    # 🔴 もとは `TagContainer` のクラスメソッドだったが、⚠ **本文を組む利用側が
    # 「タグの容れ物」越しに呼ぶ形**になっていた（`pooza/makoto2#280`）。
    # ⚠ **中身は動かしていない。置き場所だけを移した。**
    #
    # ⚠ `TagContainer.to_utf8` / `.relabel_binary` は**委譲で残してある**ので、
    # `v2.0.0` 以降の呼び出しはそのまま動く。
    module Text
      # ⚠⚠ **入口で UTF-8 を保証する (#248)。** 押し込まれた文字列が UTF-8 である
      # ことを決め打ちして検査しない実装は、入口ごとに **4 通りに挙動が割れる**。
      #
      #   不正バイト列 → ArgumentError（型が不明瞭で捕まえにくい）
      #   Shift_JIS    → 🔴 **黙って中身が消える**／🔴 **黙って false**／NoMethodError
      #
      # ⚠ **UTF-8 に寄せられるものは寄せ**（Shift_JIS など）、**寄せられないものは
      # 弾いて呼び側に返す**。⚠⚠ **scrub で黙って直さないこと** —
      # "\xE3\x81ほげ" が "�ほげ" になり、**化けたタグが投稿される**。
      #
      # ⚠⚠ **`entry` は「どの入口で弾かれたか」(#263)。** 🔴 呼び出し元が
      # 6 通りあるので、⚠ 例外メッセージにこれが無いと**利用側のログだけでは
      # backtrace を読むまで切り分けられない**。省略できるのは委譲のため。
      def self.to_utf8(value, entry = nil)
        string = value.to_s
        string = relabel_binary(string) if string.encoding == Encoding::BINARY
        unless string.encoding == Encoding::UTF_8
          begin
            string = string.encode(Encoding::UTF_8)
          rescue EncodingError => e
            message = "cannot convert to UTF-8 (#{string.encoding}): #{e.message}"
            raise ValidateError, annotate(message, entry)
          end
        end
        return string if string.valid_encoding?
        raise ValidateError, annotate('invalid byte sequence in UTF-8', entry)
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
      # ⚠ **妥当でなければ触らない。**`"abc\xFF".b` は従来どおり上の encode が弾く
      # （#248 の「寄せられないものは黙って落とさない」は変えていない）。
      def self.relabel_binary(string)
        relabeled = string.dup.force_encoding(Encoding::UTF_8)
        return relabeled.valid_encoding? ? relabeled : string
      end

      # ⚠ 入口が分かっているときだけ添える。🔴 **前に付けない** — 利用側が
      # メッセージの頭で振り分けている場合に壊すため。
      def self.annotate(message, entry)
        return message unless entry
        return "#{message} (at #{entry})"
      end
    end
  end
end
