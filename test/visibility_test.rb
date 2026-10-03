module Ginseng
  module Fediverse
    # 「外へ出してよい公開範囲か」の判定 (#302)。
    #
    # ⚠ 通信しない形で測る — `fetch_status` だけを差し替え、**本物の `NoteURI` /
    # `TootURI`** に判定させる。
    class VisibilityTest < TestCase
      NOTE_URL = 'https://misskey.example.com/notes/9abcdefghi'.freeze
      TOOT_URL = 'https://mstdn.example.com/@pooza/456'.freeze

      def test_public_note
        assert_predicate(note('visibility' => 'public'), :public?)
        assert_predicate(note('visibility' => 'public', 'localOnly' => false), :public?)
        assert_false(note('visibility' => 'public').local_only?)
      end

      # 🔴🔴 **本件の芯。** 連合なしのノートは `visibility` が `public` のまま。
      def test_local_only_note_is_not_public
        uri = note('visibility' => 'public', 'localOnly' => true)

        assert_predicate(uri, :local_only?)
        assert_false(uri.public?)
      end

      def test_non_public_note
        ['home', 'followers', 'specified'].each do |visibility|
          assert_false(note('visibility' => visibility).public?, visibility)
        end
      end

      # ⚠ 本家 Mastodon は `local_only` を返さない。**無ければ公開のまま。**
      def test_public_toot
        assert_predicate(toot('visibility' => 'public'), :public?)
        assert_predicate(toot('visibility' => 'public', 'local_only' => false), :public?)
        assert_false(toot('visibility' => 'public').local_only?)
      end

      # 🔴 glitch-soc / Hometown の連合なし。
      def test_local_only_toot_is_not_public
        uri = toot('visibility' => 'public', 'local_only' => true)

        assert_predicate(uri, :local_only?)
        assert_false(uri.public?)
      end

      def test_non_public_toot
        ['unlisted', 'private', 'direct'].each do |visibility|
          assert_false(toot('visibility' => visibility).public?, visibility)
        end
      end

      private

      def note(status)
        return stub(NoteURI.parse(NOTE_URL), status)
      end

      def toot(status)
        return stub(TootURI.parse(TOOT_URL), status)
      end

      def stub(uri, status)
        assert_predicate(uri, :valid?)
        uri.service.define_singleton_method(:fetch_status) {|_id| status}
        return uri
      end
    end
  end
end
