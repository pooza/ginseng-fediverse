module Ginseng
  module Fediverse
    # ストリーミングの URL とヘッダ (#334)。
    #
    # 🔴 **トークンを URL に載せない。** クエリは逆プロキシのアクセスログにそのまま残るので、
    # `Authorization: Bearer` で渡す（Mastodon も Misskey もヘッダを受ける）。
    class StreamingTest < TestCase
      TOKEN = 'streaming-secret-token'.freeze

      # ⚠ Pleroma は Mastodon を、Meisskey は Misskey を継承している。継承先も同じ形か見る。
      SERVICES = [MastodonService, PleromaService, MisskeyService, MeisskeyService].freeze

      def create_service(service_class, token: TOKEN)
        service = service_class.new(Ginseng::URI.parse('https://example.com/'))
        service.define_singleton_method(:info) do
          {'urls' => {'streaming_api' => 'wss://streaming.example.com'}}
        end
        service.token = token
        return service
      end

      # 🔴🔴 **本丸。** URL のどこにもトークンが出ない。
      def test_uri_does_not_carry_the_token
        SERVICES.each do |service_class|
          uri = create_service(service_class).streaming_uri

          assert_not_include(uri.to_s, TOKEN, service_class.name)
          assert_not_include(uri.query_values.to_h.keys, 'access_token', service_class.name)
          assert_not_include(uri.query_values.to_h.keys, 'i', service_class.name)
        end
      end

      def test_headers_carry_the_token
        SERVICES.each do |service_class|
          assert_equal({'Authorization' => "Bearer #{TOKEN}"},
            create_service(service_class).streaming_headers, service_class.name)
        end
      end

      # ⚠ トークンが無ければヘッダも付けない（`Bearer ` だけを送らない）。
      def test_headers_without_a_token
        SERVICES.each do |service_class|
          assert_equal({}, create_service(service_class, token: nil).streaming_headers,
            service_class.name)
        end
      end

      # ⚠ トークン以外は従来どおり。Mastodon は申告されたホストと `stream`、Misskey は本体の `wss`。
      def test_uri_keeps_the_rest
        mastodon = create_service(MastodonService).streaming_uri

        assert_equal('wss://streaming.example.com/api/v1/streaming?stream=user', mastodon.to_s)
        assert_equal({'stream' => 'public'},
          create_service(MastodonService).streaming_uri('public').query_values)

        misskey = create_service(MisskeyService).streaming_uri

        assert_equal('wss://example.com/streaming', misskey.to_s)
      end

      # ⚠ 呼ぶたびに別の hash を返す（呼び側が書き足しても次に持ち越さない）。
      def test_headers_are_fresh
        service = create_service(MastodonService)
        service.streaming_headers['X-Trace'] = 'abc'

        assert_equal({'Authorization' => "Bearer #{TOKEN}"}, service.streaming_headers)
      end
    end
  end
end
