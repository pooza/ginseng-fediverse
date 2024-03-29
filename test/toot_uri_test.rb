module Ginseng
  module Fediverse
    class TootURITest < TestCase
      def setup
        @uris = {
          mastodon: TootURI.parse('https://st.mstdn.b-shock.org/web/statuses/108222959225531814'),
          pleroma: TootURI.parse('https://leroma.shrieker.net/notice/ABlMankKYujQhR84WW'),
        }
      end

      def test_id
        assert_equal(108_222_959_225_531_814, @uris[:mastodon].id)
        assert_equal('ABlMankKYujQhR84WW', @uris[:pleroma].id)
      end

      def test_service
        assert_kind_of(MastodonService, @uris[:mastodon].service)
        assert_kind_of(MastodonService, @uris[:pleroma].service)
      end

      def test_subject
        assert(@uris[:mastodon].subject.start_with?('うどん'))
        assert(@uris[:pleroma].subject.start_with?('羽田空港'))
      end
    end
  end
end
