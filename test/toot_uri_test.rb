module Ginseng
  module Fediverse
    class TootURITest < TestCase
      def setup
        @uris = {
          mastodon: TootURI.parse('https://st.mstdn.b-shock.org/web/statuses/106057223567166956'),
          pleroma: TootURI.parse('https://leroma.shrieker.net/notice/ABlMankKYujQhR84WW'),
        }
      end

      def test_id
        assert_equal(@uris[:mastodon].id, 106_057_223_567_166_956)
        assert_equal(@uris[:pleroma].id, 'ABlMankKYujQhR84WW')
      end

      def test_service
        assert_kind_of(MastodonService, @uris[:mastodon].service)
        assert_kind_of(MastodonService, @uris[:pleroma].service)
      end

      def test_subject
        assert(@uris[:mastodon].subject.start_with?('ネギトロ丼'))
        assert(@uris[:pleroma].subject.start_with?('羽田空港'))
      end
    end
  end
end
