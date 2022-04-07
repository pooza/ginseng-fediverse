module Ginseng
  module Fediverse
    class NoteURITest < TestCase
      def setup
        @uris = {
          misskey: NoteURI.parse('https://dev.mis.b-shock.org/notes/8kjdew1qgd'),
          meisskey: NoteURI.parse('https://st.reco.shrieker.net/notes/7179245f89349aea2ea290f0'),
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
      end
    end
  end
end
