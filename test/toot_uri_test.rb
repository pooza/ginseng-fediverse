module Ginseng
  module Fediverse
    class TootURITest < TestCase
      def setup
        @uris = {
          mastodon: TootURI.parse('https://st.mstdn.b-shock.org/web/statuses/108087957312825264'),
          pleroma: TootURI.parse('https://leroma.shrieker.net/notice/ABlMankKYujQhR84WW'),
        }
      end

      def test_id
        assert_equal(108_087_957_312_825_264, @uris[:mastodon].id)
        assert_equal('ABlMankKYujQhR84WW', @uris[:pleroma].id)
      end

      def test_service
        assert_kind_of(MastodonService, @uris[:mastodon].service)
        assert_kind_of(MastodonService, @uris[:pleroma].service)
      end

      def test_subject
        assert(@uris[:mastodon].subject.start_with?('モーニングセット'))
        assert(@uris[:pleroma].subject.start_with?('羽田空港'))
      end
    end
  end
end
