module Ginseng
  module Fediverse
    class NoteURITest < TestCase
      def setup
        @uris = {
          misskey: NoteURI.parse('https://dev.mis.b-shock.org/notes/8kjdew1qgd'),
          meisskey: NoteURI.parse('https://dev.mei.b-shock.org/notes/7178ca821b99d7996c6c7fe4'),
        }
      end

      def test_id
        assert_equal(@uris[:misskey].id, '8kjdew1qgd')
        assert_equal(@uris[:meisskey].id, '7178ca821b99d7996c6c7fe4')
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
