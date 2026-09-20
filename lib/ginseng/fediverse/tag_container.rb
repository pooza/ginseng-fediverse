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

      def member?(tag)
        return super(self.class.to_utf8(tag, entry_label).to_hashtag_base)
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

      def create_pattern(tag)
        return Regexp.new("#{tag.to_hashtag}([^[:word:]]|$)")
      end
    end
  end
end
