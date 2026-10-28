module Ginseng
  module Fediverse
    # 取得した投稿を読むところ (#319)。
    class StatusURIFetchTest < TestCase
      TOOT_URL = 'https://mstdn.example.com/@pooza/123'.freeze
      NOTE_URL = 'https://misskey.example.com/notes/abc123'.freeze

      # error の応答を覚えると、2 回目は例外なしで error の Hash を返していた。
      def test_error_response_is_not_memoized
        [
          [TootURI, TOOT_URL, {'error' => 'broken'}],
          [NoteURI, NOTE_URL, {'error' => {'message' => 'broken'}}],
        ].each do |uri_class, url, body|
          uri = stub(uri_class.parse(url), body)

          2.times {assert_raises(Ginseng::GatewayError, uri_class.name) {uri.status}}
        end
      end

      def test_subject_without_body
        assert_equal('', stub(TootURI.parse(TOOT_URL), {'content' => nil}).subject)
        assert_equal('', stub(NoteURI.parse(NOTE_URL), {'text' => nil, 'cw' => nil}).subject)
      end

      # subject は取得した投稿の本文を書き換えていた（HTML が消える）。
      def test_subject_does_not_modify_status
        [
          [TootURI, TOOT_URL, 'content'],
          [TootURI, TOOT_URL, 'spoiler_text'],
          [NoteURI, NOTE_URL, 'text'],
          [NoteURI, NOTE_URL, 'cw'],
        ].each do |uri_class, url, key|
          body = {key => +'<p>hello <b>world</b> https://a.example/</p>'}
          uri = stub(uri_class.parse(url), body)

          assert_equal('hello world ', uri.subject, key)
          assert_equal('<p>hello <b>world</b> https://a.example/</p>', uri.status[key], key)
        end
      end

      private

      def stub(uri, body)
        uri.service.define_singleton_method(:fetch_status) {|_id, _params = {}| body}
        return uri
      end
    end
  end
end
