module Ginseng
  module Fediverse
    # 投稿 (`POST /api/v1/statuses`) で上流へ渡すオプション。
    #
    # ⚠⚠ **リダイレクトを追わないこと**（pooza/makoto2#282）。追うと POST が GET に化けて
    # body が捨てられ、資格情報を含むヘッダが別ホストへ送られる。
    class MastodonServicePostTest < TestCase
      # POST の引数を捕まえるだけの http スタブ。
      class CapturingHTTP
        attr_reader :uri, :options

        def post(uri, options = {})
          @uri = uri
          @options = options
          return nil
        end
      end

      def setup
        @http = CapturingHTTP.new
        @service = MastodonService.new(Ginseng::URI.parse('https://mstdn.example.com/'))
        @service.instance_variable_set(:@http, @http)
      end

      def test_post_does_not_follow_redirects
        @service.post('本文')

        assert_equal('/api/v1/statuses', @http.uri)
        assert_false(@http.options[:follow_redirects])
      end

      # ⚠ **既存の組み立てを変えない**（本文・返信先・ヘッダ）。
      def test_post_keeps_the_body_and_the_headers
        @service.post('本文', {reply: {id: '42'}})

        assert_equal({status: '本文', in_reply_to_id: '42'}, @http.options[:body])
        assert_predicate(@http.options[:headers], :present?)
      end
    end
  end
end
