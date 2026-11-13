module Ginseng
  module Fediverse
    # ストリーミングの URL とヘッダ (#334)。
    #
    # 🔴 **トークンを URL に載せない。** クエリは逆プロキシのアクセスログにそのまま残るので、
    # `Authorization: Bearer` で渡す（Mastodon と Misskey 13.14.0 以降はヘッダを受ける）。
    # ⚠⚠ **Pleroma と Meisskey はヘッダを受けない。**Pleroma は `Sec-WebSocket-Protocol`、Meisskey はクエリ。
    class StreamingTest < TestCase
      TOKEN = 'streaming-secret-token'.freeze

      SERVICES = [MastodonService, MisskeyService].freeze

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
        SERVICES.product([nil, '']).each do |service_class, token|
          assert_equal({}, create_service(service_class, token:).streaming_headers,
            [service_class.name, token].inspect)
        end
      end

      # 🔴🔴 **Pleroma と Meisskey は、継承で Mastodon / Misskey の形にしない。** ヘッダを読まないので、
      # 認証されなくなる（Meisskey は黙って匿名になる）。
      # 🔴 Pleroma はトークンを `Sec-WebSocket-Protocol` で渡し、URL にもヘッダにも載せない。
      def test_pleroma_uses_the_subprotocol
        pleroma = create_service(PleromaService)

        assert_equal('wss://streaming.example.com/api/v1/streaming?stream=user', pleroma.streaming_uri.to_s)
        assert_not_include(pleroma.streaming_uri.to_s, TOKEN)
        assert_equal({}, pleroma.streaming_headers)
        assert_equal([TOKEN], pleroma.streaming_protocols)
      end

      # ⚠ トークンが無ければサブプロトコルも付けない。
      def test_pleroma_protocols_without_a_token
        [nil, ''].each do |token|
          assert_equal([], create_service(PleromaService, token:).streaming_protocols, token.inspect)
        end
      end

      # ⚠ Meisskey はヘッダを読まないのでクエリのまま（ヘッダにすると黙って匿名になる）。
      def test_meisskey_keeps_the_query
        meisskey = create_service(MeisskeyService)

        assert_equal({'i' => TOKEN}, meisskey.streaming_uri.query_values)
        assert_equal('wss', meisskey.streaming_uri.scheme)
        assert_equal({}, meisskey.streaming_headers)
      end

      # Pleroma 以外はサブプロトコルにトークンを載せない。
      def test_protocols_are_empty_elsewhere
        [MastodonService, MisskeyService, MeisskeyService].each do |service_class|
          assert_equal([], create_service(service_class).streaming_protocols, service_class.name)
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
