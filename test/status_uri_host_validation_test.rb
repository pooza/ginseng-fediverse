require 'socket'

module Ginseng
  module Fediverse
    # `TootURI` / `NoteURI` が投稿を取りにいく先のホストを検証する (#306)。
    #
    # ⚠⚠ **本物のソケットで測る。** 守りたいのは「要求が出ていかないこと」で、
    # `fetch_status` を差し替えると、その手前で落ちたのか差し替えが黙らせたのかを
    # 区別できない。
    # ⚠ このテストは外へ出ない — 相手は 127.0.0.1 に立てたサーバーだけ。
    class StatusURIHostValidationTest < TestCase
      # 受けた要求の先頭行を溜めるだけのサーバー。
      class Recorder
        attr_reader :requests, :port

        def initialize(status: '200 OK', headers: {}, body: '{}')
          @requests = []
          @server = TCPServer.new('127.0.0.1', 0)
          @port = @server.addr[1]
          response = ["HTTP/1.1 #{status}", 'Content-Type: application/json',
            "Content-Length: #{body.bytesize}", 'Connection: close',
            *headers.map {|k, v| "#{k}: #{v}"}, '', body].join("\r\n")
          @thread = Thread.new {serve(response)}
        end

        def close
          @thread.kill
          @server.close
        end

        private

        def serve(response)
          loop do
            socket = @server.accept
            @requests.push(socket.gets.to_s.strip)
            length = 0
            while (line = socket.gets) && line != "\r\n"
              length = line.split(':', 2).last.to_i if line.match?(/\Acontent-length:/i)
            end
            socket.read(length) if length.positive?
            socket.write(response)
            socket.close
          end
        rescue IOError
          nil
        end
      end

      # ⚠ 利用側を模す。**`service` を丸ごと上書きして、自前のサービスクラスを返す**
      # （`mulukhiya-toot-proxy` の形）。検証を gem の `service` に置くと、ここで外れる。
      class ForeignHTTP < Ginseng::HTTP; end

      class ForeignMastodonService < MastodonService
        def http_class
          return ForeignHTTP
        end
      end

      class ForeignMisskeyService < MisskeyService
        def http_class
          return ForeignHTTP
        end
      end

      module Foreign
        attr_accessor :validator

        def host_validator
          return validator
        end

        def service
          unless @service
            uri = clone
            uri.path = '/'
            @service = foreign_service_class.new(uri)
            @service.token = nil
          end
          return @service
        end
      end

      class ForeignTootURI < TootURI
        include Foreign

        def foreign_service_class
          return ForeignMastodonService
        end
      end

      class ForeignNoteURI < NoteURI
        include Foreign

        def foreign_service_class
          return ForeignMisskeyService
        end
      end

      def setup
        @recorders = []
      end

      def teardown
        super
        @recorders.each(&:close)
      end

      # 🔴🔴 **本件の芯。** 既定のままでは、内部のアドレスへ要求が出ていかない。
      def test_default_rejects_an_internal_host_before_sending
        server = recorder
        [
          TootURI.parse("http://127.0.0.1:#{server.port}/@pooza/1"),
          NoteURI.parse("http://127.0.0.1:#{server.port}/notes/9abc"),
        ].each do |uri|
          assert_predicate(uri, :valid?)
          error = assert_raise(Ginseng::GatewayError) {uri.public?}
          assert_match(/Rejected host/, error.message, uri.class.name)
        end

        assert_empty(server.requests)
      end

      # ⚠ 既定は `ginseng-core` の既製品。🔴 ここを真偽を返すだけの lambda に替えると、
      # 接続先が固定されなくなる（DNS リバインディング）。
      def test_default_is_the_public_host_validator
        [TootURI.parse('https://mstdn.example.com/@pooza/1'),
          NoteURI.parse('https://misskey.example.com/notes/9abc')].each do |uri|
          assert_nil(uri.host_validator.call('127.0.0.1'), uri.class.name)
          assert_nil(uri.host_validator.call('localhost'), uri.class.name)
        end
      end

      # 🔴🔴 **`service` を上書きした利用側にも届く。**
      def test_reaches_a_consumer_that_overrides_service
        server = recorder
        seen = []
        [
          ForeignTootURI.parse("http://127.0.0.1:#{server.port}/@pooza/1"),
          ForeignNoteURI.parse("http://127.0.0.1:#{server.port}/notes/9abc"),
        ].each do |uri|
          uri.validator = lambda do |host|
            seen.push(host)
            next false
          end

          assert_raise(Ginseng::GatewayError) {uri.public?}
        end

        assert_equal(['127.0.0.1', '127.0.0.1'], seen)
        assert_empty(server.requests)
      end

      # ⚠⚠ **nil を返せば検証しない**（自サーバーが内部アドレスに解決される構成の逃げ道）。
      def test_nil_validator_skips_validation
        toots = recorder(body: '{"visibility":"public"}')
        notes = recorder(body: '{"visibility":"public","localOnly":false}')
        toot = ForeignTootURI.parse("http://127.0.0.1:#{toots.port}/@pooza/1")
        note = ForeignNoteURI.parse("http://127.0.0.1:#{notes.port}/notes/9abc")

        assert_predicate(toot, :public?)
        assert_predicate(note, :public?)
        assert_equal(['GET /api/v1/statuses/1 HTTP/1.1'], toots.requests)
        assert_equal(['POST /api/notes/show HTTP/1.1'], notes.requests)
      end

      # ⚠ 通した相手には、従来と同じ要求が 1 回だけ出る。
      def test_accepted_host_is_fetched_once
        toots = recorder(body: '{"visibility":"public"}')
        notes = recorder(body: '{"visibility":"public","localOnly":false}')
        toot = ForeignTootURI.parse("http://127.0.0.1:#{toots.port}/@pooza/1")
        note = ForeignNoteURI.parse("http://127.0.0.1:#{notes.port}/notes/9abc")
        [toot, note].each {|uri| uri.validator = ->(_host) {true}}

        assert_predicate(toot, :public?)
        assert_predicate(note, :public?)
        assert_equal(['GET /api/v1/statuses/1 HTTP/1.1'], toots.requests)
        assert_equal(['POST /api/notes/show HTTP/1.1'], notes.requests)
      end

      # 🔴 **検証を通しても、リダイレクトは追わない（従来どおり）。**
      #
      # ⚠⚠ validator を渡すと `Ginseng::HTTP` はリダイレクトを自前で追う経路に入る。
      # 追わないのは `RedirectGuard` が「資格情報あり」と見て止めているからで
      # （3xx は `GatewayError` になる）、**ここが追う側へ変わると、判定に使う投稿が
      # 別ホストから来る**。
      def test_accepted_host_does_not_follow_redirects
        target = recorder(body: '{"visibility":"public"}')
        location = "http://127.0.0.1:#{target.port}/api/v1/statuses/1"
        hop = recorder(status: '302 Found', headers: {'Location' => location}, body: '')
        toot = ForeignTootURI.parse("http://127.0.0.1:#{hop.port}/@pooza/1")
        toot.validator = ->(_host) {true}

        error = assert_raise(Ginseng::GatewayError) {toot.public?}
        assert_match(/Bad response 302/, error.message)
        assert_equal(1, hop.requests.size)
        assert_empty(target.requests)
      end

      private

      def recorder(**)
        @recorders.push(Recorder.new(**))
        return @recorders.last
      end
    end
  end
end
