require 'nokogiri'

module Ginseng
  module Fediverse
    include Package

    class Parser
      include Package

      attr_reader :text, :body, :footer, :footer_tags
      attr_accessor :max_length, :service

      def initialize(text = '')
        @config = config_class.instance
        @logger = logger_class.new
        @service = default_service rescue nil
        @max_length = default_max_length rescue nil
        @footer_tags = tag_container_class.new
        self.text = text || ''
      end

      alias to_s text

      def nokogiri
        return text.nokogiri
      end

      def accts(&block)
        return enum_for(__method__) unless block
        text.scan(Parser.acct_pattern).map(&:first).map {|v| Acct.new(v)}.each(&block)
      end

      def uris(&block)
        return enum_for(__method__) unless block
        URI.scan(text).each(&block)
      end

      def text=(text)
        @text = text.to_s.strip
        @params = nil
        @footer_tags.clear
        lines = self.class.sanitize(text).each_line.to_a
        lines.dup.reverse_each do |line|
          break unless line.match?(/^[[:blank:]]*(#[^[:blank:]]+[[:blank:]]?)+[[:blank:]]*$/)
          @footer_tags.merge(lines.pop.strip.split(/[[:blank:]]+/))
        end
        @body = lines.map(&:chomp).join("\n").strip
        @footer = @footer_tags.map(&:to_hashtag).join(' ')
      end

      def to_md
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def nowplaying?
        return /#nowplaying[[:blank:]]/i.match?(text)
      end

      def length
        length = text.length
        length -= uris.sum {|v| v.to_s.length - service.characters_reserved_per_url}
        length -= accts.sum {|v| v.to_s.length - v.username.length - 1}
        return length
      end

      alias size length

      def too_long?
        return max_length < length
      end

      def exec
        if @params.nil?
          @params = YAML.safe_load(text)
          @params = JSON.parse(text) unless @params.is_a?(Hash)
          @params = false unless @params.is_a?(Hash)
        end
        return @params || nil
      rescue Psych::SyntaxError, JSON::ParserError
        return nil
      rescue Psych::Exception, JSON::JSONError => e
        return @logger.error(e)
      end

      alias params exec

      def hashtags
        return tag_container_class.scan(text)
      end

      alias tags hashtags

      def command?
        return true if params.key?('command')
        return true if text.start_with?('c:') && params.key?('c')
        return false
      rescue
        return false
      end

      def command_name
        if text.start_with?('c:')
          params['command'] ||= params['c']
          params.delete('c')
        end
        return params['command']
      rescue
        return nil
      end

      alias command command_name

      def to_sanitized
        return Parser.sanitize(text)
      end

      def default_max_length
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def default_service
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def self.sanitize(text)
        text = text.to_s.dup
        text.delete!("\n") if text.match?(/<br.*?>/)
        text.gsub!(/[[:blank:]]*<br.*?>/, "\n")
        text.gsub!(%r{[[:blank:]]*</p.*?>}, "\n\n")
        text.gsub!(/<p.*?>/, '')
        text.sanitize!
        return text.strip
      end

      # 本文からタグを**抽出**するパターン (#275)。
      #
      # ⚠⚠ **投稿先の正規表現をそのまま引く。** 写しているのは
      # **Mastodon v4.7.2 の `Tag::HASHTAG_RE`**（`app/models/tag.rb`）。🔴 **元の形は
      # 2017-03 の写しのまま止まっており**、全角 `＃`（v4.5.0 #36103）と
      # 直前の条件（v4.6.0 #37684 / #38212）と区切り文字（v3.0.0 #11345 / #11821）を
      # 取りこぼしていた。⚠ **上流が次に変えたらまた追随する**ので、
      # どの版を写したかをここに残すこと。
      #
      # 🔴🔴 **中黒 `・`（U+30FB）だけは意図して外してある**（Mastodon は v4.1.0 #22888 で
      # 区切りに入れている）。⚠⚠ **この gem では長年タグにならず、その前提で運用されている** —
      # 認識だけ入れても `TagContainer#create_tags` が `to_hashtag` を通すので、
      # 🔴 `#プリキュア・オールスターズ` から `#プリキュア_オールスターズ` が**生成される側へ回る**。
      # `_` と `・` は Mastodon の正規化でも別のタグなので、積み上がったタグが割れる。
      # ⚠⚠ **「完全互換」へ揃えるときに黙って外さないこと。**
      def self.hashtag_pattern
        return create_hashtag_pattern(Config.instance['/hashtag/pattern'])
      end

      # 本文を投稿先に再解釈させないための**無毒化**用パターン (#275)。
      #
      # ⚠⚠ **タグ名は抽出と共有し、境界（直前の条件）だけ広く取る。**
      # 🔴 **無毒化と抽出は安全側の向きが逆** — 抽出は「正確」、無毒化は「広く」。
      #
      # ⚠⚠ **相手は Mastodon だけではないので、境界を Mastodon へ揃えると穴が開く**。
      # 実測（mfm-js 0.26.0 を走らせた）: Misskey は**直前が ASCII 英数でなければタグにする**ので、
      # 🔴 `search／#サーチ2` `あ#タグ` `##tag` は**リンク化される**（Mastodon はどれもしない）。
      #
      # 🔴🔴 **広げるのは半角 `#` の側だけ (#275 Codex P2)。** 全角 `＃` は **Misskey がそもそも
      # タグにしない**ので、広げても守る相手がいない。⚠⚠ **守る相手がいない置換は、
      # ただ本文を壊すだけ** — 実測で `あ＃タグ` `（＃タグ` は Mastodon も Misskey もタグにしない。
      # ⚠ #273 で `H@ppy Together!!!` を `H@ ppy` にしていたのと同じ失敗の形。
      def self.hashtag_sigil_pattern
        return create_hashtag_pattern(Config.instance['/hashtag/sigil_pattern'])
      end

      # ⚠ `%{name}` を展開する。🔴 **ブロック形式で渡すこと** —
      # 置換文字列に渡すと `\\` や `\1` が後方参照・エスケープとして食われる。
      # ⚠ `%{name}` を含まないパターン（利用側の上書き）はそのまま通る。
      #
      # 🔴🔴 **`timeout:` を必ず立てる（リリース前レビューの赤）。** ⚠⚠ タグ名は
      # Mastodon の `HASHTAG_FIRST_SEQUENCE` の写しで、**区切り（`·` / ZWNJ）が
      # `[[:word:]]` ではないのに途中に許される**ため、`#a` のあとに区切りが続く
      # 本文で**二次爆発**する（実測: 30KB で 12.7 秒、旧パターンは 0.0013 秒）。
      # 🔴 上流は**自分のユーザーが書いた上限付きの本文**にしか当てないが、こちらは
      # **`sanitize_status` 経由で遠隔のフィード本文**に当たる（`tomato-shrieker` の
      # RSS の `title` / iCal の `description`。長さの上限は無い）。
      # ⚠⚠ **握り潰さない** — 無毒化できなかった本文を黙って投稿するほうが危ない。
      def self.create_hashtag_pattern(pattern)
        name = Config.instance['/hashtag/name']
        return Regexp.new(
          pattern.gsub('%{name}') {name},
          Regexp::IGNORECASE,
          timeout: Config.instance['/hashtag/timeout'],
        )
      end

      def self.acct_pattern
        return Regexp.new(Config.instance['/acct/pattern'], Regexp::IGNORECASE)
      end

      # 本文を投稿先に再解釈させないための**無毒化**用パターン。
      #
      # ⚠⚠ **名前の部分は抽出と同じで、境界（直前の条件）だけ広く取る**
      # （`hashtag_sigil_pattern` と同じ理由 — 抽出は「正確」、無毒化は「広く」）。
      # 🔴 抽出用の `acct_pattern` を当てていたので、**Misskey がメンションにする
      # `ラブ@pooza` `_@admin` を素通りしていた**（Mastodon は `[[:word:]]` 判定なので無事）。
      def self.acct_sigil_pattern
        return Regexp.new(Config.instance['/acct/sigil_pattern'], Regexp::IGNORECASE)
      end

      # 無毒化で丸ごと除外する URL の範囲（理由は config/lib.yaml の `sigil/url_pattern`）。
      # 🔴 **`IGNORECASE` を付けない (#298)** — mfm-js は大文字の scheme を URL と読まない。
      def self.sigil_url_pattern
        return Regexp.new(Config.instance['/sigil/url_pattern'])
      end
    end
  end
end
