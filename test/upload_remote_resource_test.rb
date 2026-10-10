require 'socket'

module Ginseng
  module Fediverse
    # リモートの添付を取りに行く口の、リダイレクトの扱い (#311) とホストの検証 (#312)。
    #
    # ⚠⚠ **`HTTParty` を差し替えず、実際にソケットで応答する。** 見たいのは
    # 「ガードを挿した `http` が、この口では 3xx を追う」ことで、追うのは HTTParty の
    # 中なので、継ぎ目を差し替えると測れない。
    class UploadRemoteResourceTest < TestCase
      BODY = 'IMAGE-BYTES'.freeze

      # ⚠ `upload` は投稿先へ出るので、渡されたファイルの中身を控えるだけにする。
      class CapturingService < MastodonService
        attr_reader :uploaded, :upload_params

        def upload(path, params = {})
          @uploaded = File.read(path)
          @upload_params = params
          return :uploaded
        end
      end

      # ⚠ 利用側を模した、検証を差し替えたサービス。ループバックだけを通す
      # （テストのサーバーは 127.0.0.1 に居て、既定の検証では初段で落ちる）。
      class LoopbackService < CapturingService
        def remote_resource_host_validator
          return ->(host) {host == '127.0.0.1'}
        end
      end

      def setup
        @requests = []
        @server = TCPServer.new('127.0.0.1', 0)
        @port = @server.addr[1]
        @thread = Thread.new {serve}
        @service = LoopbackService.new(Ginseng::URI.parse('https://mstdn.example.com/'))
      end

      def teardown
        @thread&.kill
        @thread&.join(1)
        @server&.close
      end

      # 🔴 **資格情報らしい名前をクエリに持つ URL でも、3xx を追って取れること。**
      # ⚠ `token` は `ginseng-core` 2.0.0 から、`X-Amz-Signature` は 2.4.1 から
      # ガードの対象。直す前はどちらも `GatewayError: Bad response 302` だった。
      def test_follows_redirect_even_with_credential_like_query
        ['token=x', 'X-Amz-Signature=x'].each do |query|
          @requests.clear

          assert_equal(:uploaded, @service.upload_remote_resource("http://127.0.0.1:#{@port}/first?#{query}"))
          assert_equal(BODY, @service.uploaded, query)
          assert_equal(["/first?#{query}", '/final'], @requests, query)
        end
      end

      # ⚠ クエリを持たない URL は、直す前から追っていた（変えていないことを見る）。
      def test_follows_redirect_without_query
        @service.upload_remote_resource("http://127.0.0.1:#{@port}/first")

        assert_equal(BODY, @service.uploaded)
      end

      # 🔴🔴 **userinfo を持つ URL は、この口でも追わない（リリース前レビュー）。**
      # ⚠⚠ 追うと、HTTParty が userinfo から作った Basic を**同じホストの別ポートや
      # `http`** へ再送する（ホスト名しか比べないため）。⚠ 一律に明示していた初版は、
      # ガードの userinfo の判定まで素通ししていた。
      def test_does_not_follow_redirect_with_userinfo
        assert_raise(GatewayError) do
          @service.upload_remote_resource("http://user:pass@127.0.0.1:#{@port}/first")
        end
        assert_equal(['/first'], @requests)
        assert_nil(@service.uploaded)
      end

      # 🔴🔴 **既定では、内部のホストへ要求を出さない (#312)。** ⚠⚠ 検証を差し替えていない
      # サービスで見る — 差し替えた側だけ測っても、既定が守っていることは分からない。
      # ⚠ 要求が 1 本も届いていないこと（落とすのは接続の前）。
      def test_default_validator_rejects_internal_host
        service = CapturingService.new(Ginseng::URI.parse('https://mstdn.example.com/'))
        ["http://127.0.0.1:#{@port}/first", "http://localhost:#{@port}/final"].each do |url|
          error = assert_raise(GatewayError) {service.upload_remote_resource(url)}

          assert_match(/Rejected host/, error.message, url)
        end
        assert_empty(@requests)
        assert_nil(service.uploaded)
      end

      # ⚠ 既定は `Ginseng::PublicHost` の判定そのもの（写しを持たない）。
      def test_default_validator_is_public_host
        validator = CapturingService.new(Ginseng::URI.parse('https://mstdn.example.com/')).remote_resource_host_validator

        assert_nil(validator.call('127.0.0.1'))
        assert_nil(validator.call('169.254.169.254'))
        assert_nil(validator.call('localhost'))
      end

      # 🔴 **リダイレクトの先も検証を通ること。** ⚠ 初段は通るホスト（127.0.0.1）で、
      # 先は通らないホスト（localhost）。公開ホストから内部へ飛ばす形の縮図。
      def test_validates_every_redirect_hop
        error = assert_raise(GatewayError) do
          @service.upload_remote_resource("http://127.0.0.1:#{@port}/elsewhere")
        end

        assert_match(/Rejected host 'localhost'/, error.message)
        assert_equal(['/elsewhere'], @requests)
        assert_nil(@service.uploaded)
      end

      # ⚠ **呼び出しごとの差し替え。** キーが在ればその値を使い、`nil` なら検証しない。
      # ⚠⚠ `upload` へは渡さず、渡された hash も書き換えない (#258)。
      def test_host_validator_param_overrides_and_is_not_forwarded
        service = CapturingService.new(Ginseng::URI.parse('https://mstdn.example.com/'))
        params = {host_validator: nil, response: :id}.freeze

        assert_equal(:uploaded, service.upload_remote_resource("http://127.0.0.1:#{@port}/final", params))
        assert_equal({response: :id}, service.upload_params)

        rejecting = {host_validator: ->(_) {false}}

        assert_raise(GatewayError) {@service.upload_remote_resource("http://127.0.0.1:#{@port}/final", rejecting)}
        assert_true(rejecting.key?(:host_validator))
      end

      # ⚠⚠ **追うのはこの口だけ。** 同じ `http` の素の GET は、ガードのとおり追わない。
      def test_guard_still_refuses_elsewhere
        assert_raise(GatewayError) {@service.http.get("http://127.0.0.1:#{@port}/first?token=x")}
        assert_equal(['/first?token=x'], @requests)
      end

      private

      # `/first…` は `/final` へ、`/elsewhere` は別のホスト名（localhost）へ 302。
      # それ以外は本文を返す。
      # ⚠ 後始末の形は `StatusURIHostValidationTest::Recorder` と同じ（要求行の無い接続が
      # 来てもスレッドを死なせない。死ぬと、次の要求が読み取りの時間切れまで待つ）。
      def serve
        loop do
          client = @server.accept
          begin
            answer(client)
          ensure
            client.close
          end
        end
      rescue IOError, SystemCallError
        nil
      end

      def answer(client)
        path = client.gets.to_s.split[1].to_s
        nil while (line = client.gets) && line != "\r\n"
        @requests.push(path)
        client.write(response_for(path))
      end

      def response_for(path)
        location = '/final' if path.start_with?('/first')
        location = "http://localhost:#{@port}/final" if path == '/elsewhere'
        if location
          return "HTTP/1.1 302 Found\r\nLocation: #{location}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        end
        return "HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: #{BODY.bytesize}\r\n" \
          "Connection: close\r\n\r\n#{BODY}"
      end
    end
  end
end
