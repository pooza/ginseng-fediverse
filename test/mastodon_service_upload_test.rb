module Ginseng
  module Fediverse
    # アップロード失敗時、上流の GatewayError を握り潰さないこと (#246)。
    #
    # かつては `ValidateError` に詰め替えていたため、上流のステータス・ボディが
    # 失われ、mulukhiya 側の 401 アラート抑止も 413 の上限超過文言も到達せず、
    # ボットの無効トークン連打がそのまま管理者へのアラートメールになっていた。
    class MastodonServiceUploadTest < TestCase
      # 上流のレスポンスを添えた GatewayError を投げる http のスタブ。
      class FailingHTTP
        Response = Struct.new(:code, :body)

        def initialize(code, body)
          @response = Response.new(code, body)
        end

        def upload(*)
          error = GatewayError.new("Bad response #{@response.code}")
          error.response = @response
          raise error
        end
      end

      def create_service(code, body = '{}')
        service = MastodonService.new(Ginseng::URI.parse('https://mstdn.example.com/'))
        service.instance_variable_set(:@http, FailingHTTP.new(code, body))
        return service
      end

      def upload(service)
        return service.upload('/path/to/image.jpg')
      end

      def test_gateway_error_is_not_swallowed
        service = create_service(401)

        assert_raise(GatewayError) {upload(service)}
      end

      # ⚠ ValidateError に詰め替えられていないこと。`ValidateError` は
      # `RequestError` の子で `GatewayError` の子ではないので、呼び側の
      # `rescue GatewayError` を素通りしてしまう。
      def test_error_is_not_converted_to_validate_error
        service = create_service(401)

        error = assert_raise(GatewayError) {upload(service)}
        assert_false(error.is_a?(ValidateError))
      end

      # 眼目。これが取れないと mulukhiya は 401 を抑止できない。
      def test_source_status_survives
        error = assert_raise(GatewayError) {upload(create_service(401))}

        assert_equal(401, error.source_status)
      end

      # 413 は「上限サイズ超過」の利用者向け文言を出すために使われる。
      def test_source_status_survives_for_size_limit
        error = assert_raise(GatewayError) {upload(create_service(413))}

        assert_equal(413, error.source_status)
      end

      # 上流が返した理由もプロキシの中で失われないこと。
      def test_source_body_survives
        error = assert_raise(GatewayError) do
          upload(create_service(422, '{"error":"Validation failed: File is invalid"}'))
        end

        assert_equal('Validation failed: File is invalid', error.source_body['error'])
      end
    end
  end
end
