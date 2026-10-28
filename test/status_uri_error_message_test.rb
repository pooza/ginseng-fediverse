module Ginseng
  module Fediverse
    # 投稿が取れないときの例外メッセージに、URL の userinfo とクエリを載せない (#322)。
    # 例外はログのマスクを通らずに呼び出し側や Sentry へ出る。
    class StatusURIErrorMessageTest < TestCase
      CASES = {
        TootURI => 'https://alice:SECRETPASS@mstdn.example.com/@pooza/123?access_token=SECRETTOKEN&x=SECRETQ#SECRETFRAG',
        NoteURI => 'https://alice:SECRETPASS@misskey.example.com/notes/abc123?i=SECRETTOKEN&x=SECRETQ#SECRETFRAG',
      }.freeze

      def test_not_found
        CASES.each do |uri_class, url|
          error = assert_raises(Ginseng::NotFoundError) {status(uri_class, url, nil)}

          assert_masked(error.message, url)
        end
      end

      def test_invalid
        CASES.each do |uri_class, url|
          body = {'error' => {'message' => 'broken'}}
          body = {'error' => 'broken'} if uri_class == TootURI
          error = assert_raises(Ginseng::GatewayError) {status(uri_class, url, body)}

          assert_masked(error.message, url)
          assert_includes(error.message, 'broken')
        end
      end

      private

      def status(uri_class, url, body)
        uri = uri_class.parse(url)
        uri.service.define_singleton_method(:fetch_status) {|_id, _params = {}| body}
        return uri.status
      end

      def assert_masked(message, url)
        refute_match(/SECRET|alice/, message, url)
        assert_includes(message, "https://#{Ginseng::URI.parse(url).host}#{Ginseng::URI.parse(url).path}")
      end
    end
  end
end
