module Ginseng
  module Fediverse
    class TagContainer < Set
      include Package

      attr_reader :text

      def add(word)
        normalized = normalize(self.class.to_utf8(word, entry_label))
        return self if normalized.empty?
        @tags = nil
        return super(normalized)
      end

      alias push add

      # ⚠⚠ **「同じタグを出力するか」で比べる (#260)。** 両辺を `create_tags` と
      # 同じ形に畳み、大文字小文字を区別しない。
      # 🔴 もとは引数だけを `to_hashtag_base` して**生の格納値**と比べていたので、
      # 空白や記号を含む値（`剣崎 真琴`）はどの形で引いても当たらず、
      # Mastodon が正規化して返すタグ名（`foobar` / `l·l·l`）も外れていた。
      #
      # ⚠ **`include?` / `===` は `Set` のまま（格納値との完全一致）。**
      # 🔴 `assert_includes` はこちらを通らない。
      #
      # ⚠ **Mastodon の ASCII folding（`café` → `cafe`）は写していない。**
      # アクセント付きのラテン文字のタグは、投稿先が返す名前では当たらない。
      def member?(tag)
        key = tag_key(normalize(self.class.to_utf8(tag, entry_label)))
        return false if key.empty?
        return stored_keys.include?(key)
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
        tag = self.class.to_utf8(tag, entry_label)
        matches = filter {|v| v.casecmp(tag).zero?}
        return nil if matches.empty?
        matches.each {|v| super(v)}
        @tags = nil
        return self
      end

      def text=(text)
        @tags = nil
        @text = self.class.to_utf8(text, entry_label).nfkc
      end

      alias body= text=

      def count
        return create_tags.count
      end

      def to_s
        return create_tags.join(' ')
      end

      def create_tags
        @tags ||= filter_map {|tag| create_tag(tag)}
          .reject {|tag| @text&.match?(create_pattern(tag))}
          .to_set
        return @tags
      end

      def self.scan(text)
        return new(
          # ⚠ `scan` 自体が不正バイト列で `ArgumentError` を上げるので、
          #   `add` へ届く前にここで検査する（#248）。
          to_utf8(text, "#{name}.#{__callee__}").scan(Parser.hashtag_pattern).map(&:first),
        )
      end

      # ⚠⚠ **中身は Text へ移した (#277)。** 本文を組む利用側が「タグの容れ物」
      # 越しに呼ぶ形になっていたため。⚠ **ここは委譲だけを残す** —
      # `v2.0.0` 以降の `TagContainer.to_utf8` の呼び出しを壊さない。
      def self.to_utf8(value, entry = nil)
        return Text.to_utf8(value, entry)
      end

      # ⚠ 同上 (#277)。`v2.0.0` で公開してしまっているので委譲で残す。
      def self.relabel_binary(string)
        return Text.relabel_binary(string)
      end

      private

      # ⚠ **どの入口で弾かれたかを例外に残す (#263)。** 🔴 入口が 6 通りあるので、
      # これが無いと**利用側のログだけでは backtrace を読むまで切り分けられない**。
      #
      # ⚠ クラス名は `self.class` から取るので、**サブクラスなら実際の名前**が出る
      # （実測: `Sub#add`）。⚠⚠ **別名は元の名前に畳まれる** — `push` は `#add`、
      # `body=` は `#text=` になる（`base_label` は定義時の名前を返すため）。
      # 🔴 **切り分けたいのは「どの経路を通ったか」なので、これで足りる。**
      def entry_label
        return "#{self.class}##{caller_locations(1, 1).first.base_label}"
      end

      # ⚠ `create_tags` と `member?` の**共通の畳み方**。片方だけ直すと、
      # 出力されるタグと `member?` の答えがまたずれる (#260)。
      def create_tag(word)
        # 🔴 **後読みで書く。** `([a-z0-9]{2,})[[:blank:]]` は空白の無い英数字の長い列で
        # 二乗に遅い（`'x' * 8000` で 0.8 秒）。置換の結果は同じ（ランダムな 20 万件で一致）。
        word = word.gsub(/(?<=[a-z0-9]{2})[[:blank:]]/i, '_').gsub(/[[:blank:]]/, '')
        return word.to_hashtag if word.present?
      end

      # ⚠ NFKC と小文字化は Mastodon の正規化（`HashtagNormalizer`）に合わせた。
      # 🔴 **NFKC は畳んだあとに掛ける** — 投稿先が正規化するのは**出力されたタグ**なので。
      # 先に掛けると `ＦＯＯ bar`（出力は `#ＦＯＯbar`）と `FOO bar`（`#FOO_bar`）が
      # 同じ `foo_bar` に畳まれ、出力と答えがずれる（実測・テストで検出）。
      #
      # 🔴🔴 **正規化のあとでもう一度畳む（Codex P2）。** NFKC は畳み方が消す文字を
      # 新しく生む（`Ŀ` → `l·`、`क़` → `क` ＋ヌクタ）。問い合わせの `l·` の `·` は最初の畳みで
      # 消えるのに、格納側の `·` は NFKC のあとで生まれるので残る。畳み直さないと非対称になる。
      def tag_key(word)
        word = create_tag(word).to_s.unicode_normalize(:nfkc).downcase
        return create_tag(word).to_s.delete_prefix('#')
      end

      # ⚠ **格納側のキーは覚えておく。** 毎回全要素を畳むと、応答のタグを `member?` で
      # 絞る呼び側（mulukhiya）で「格納数 × 問い合わせ数」になる（100 タグで 0.15 秒）。
      # 🔴 **`@tags` のように `add` / `delete` で捨てる形にしない** — `Set` の `clear` /
      # `subtract` / `keep_if` などはそこを通らない。中身の `hash` で古さを判定する。
      def stored_keys
        digest = hash
        return @stored_keys.last if @stored_keys&.first == digest
        @stored_keys = [digest, filter_map {|v| tag_key(v).presence}.to_set]
        return @stored_keys.last
      end

      def create_pattern(tag)
        return Regexp.new("#{tag.to_hashtag}([^[:word:]]|$)")
      end
    end
  end
end
