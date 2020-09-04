module Ginseng
  module Fediverse
    class NoteURITest < TestCase
      def setup
        @uri = NoteURI.parse('https://dev.mis.b-shock.org/notes/8bitvnxoxe')
      end

      def test_id
        assert_equal(@uri.id, '8bitvnxoxe')
      end

      def test_service
        assert_kind_of(MisskeyService, @uri.service)
      end
    end
  end
end
