require 'socket'

module Ginseng
  module Fediverse
    # リモートの添付を取りに行く口のリダイレクトの扱い (#311)。
    #
    # ⚠⚠ **`HTTParty` を差し替えず、実際にソケットで応答する。** 見たいのは
    # 「ガードを挿した `http` が、この口では 3xx を追う」ことで、追うのは HTTParty の
    # 中なので、継ぎ目を差し替えると測れない。
    class UploadRemoteResourceTest < TestCase
      BODY = 'IMAGE-BYTES'.freeze

      # ⚠ `upload` は投稿先へ出るので、渡されたファイルの中身を控えるだけにする。
      class CapturingService < MastodonService
        attr_reader :uploaded

        def upload(path, _params = {})
          @uploaded = File.read(path)
          return :uploaded
        end
      end

      def setup
        @requests = []
        @server = TCPServer.new('127.0.0.1', 0)
        @port = @server.addr[1]
        @thread = Thread.new {serve}
        @service = CapturingService.new(Ginseng::URI.parse('https://mstdn.example.com/'))
      end

      def teardown
        @thread.kill
        @server.close
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

      # ⚠⚠ **追うのはこの口だけ。** 同じ `http` の素の GET は、ガードのとおり追わない。
      def test_guard_still_refuses_elsewhere
        assert_raise(GatewayError) {@service.http.get("http://127.0.0.1:#{@port}/first?token=x")}
        assert_equal(['/first?token=x'], @requests)
      end

      private

      # `/first…` は `/final` へ 302、それ以外は本文を返す。
      def serve
        loop do
          client = @server.accept
          path = client.gets.to_s.split[1]
          nil while (line = client.gets) && line != "\r\n"
          @requests.push(path)
          client.write(response_for(path))
          client.close
        end
      end

      def response_for(path)
        if path.start_with?('/first')
          return "HTTP/1.1 302 Found\r\nLocation: /final\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        end
        return "HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: #{BODY.bytesize}\r\n" \
          "Connection: close\r\n\r\n#{BODY}"
      end
    end
  end
end
