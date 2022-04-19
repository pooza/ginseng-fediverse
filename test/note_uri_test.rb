module Ginseng
  module Fediverse
    class NoteURITest < TestCase
      def setup
        @uris = {
          misskey: NoteURI.parse('https://dev.mis.b-shock.org/notes/8kjdew1qgd'),
          meisskey: NoteURI.parse('https://st.reco.shrieker.net/notes/7179245f89349aea2ea290f0'),
          meisskey2: NoteURI.parse('https://reco.shrieker.net/notes/71803f6c4f4650e68b6fff0b'),
        }
      end

      def test_id
        assert_equal('8kjdew1qgd', @uris[:misskey].id)
        assert_equal('7179245f89349aea2ea290f0', @uris[:meisskey].id)
      end

      def test_service
        assert_kind_of(MisskeyService, @uris[:misskey].service)
        assert_kind_of(MisskeyService, @uris[:meisskey].service)
      end

      def test_subject
        assert(@uris[:misskey].subject.start_with?('カレーうどん'))
        assert(@uris[:meisskey].subject.start_with?('カレー将軍'))
        assert_equal('EPGStationむけに今まで作った単発スクリプトを、パッケージにまとめてます。tomato-shriekerと併用して、録画情報を投稿するボットを作ったりするのに使います。 需要のことなど知るか！w #Reco #github_com #GitHub #EPGStation #image', @uris[:meisskey2].subject)
      end
    end
  end
end
