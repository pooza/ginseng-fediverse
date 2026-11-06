module Ginseng
  module Fediverse
    # 投稿先へ出す要求のリダイレクトの扱い (#280 / #282)。
    #
    # ⚠⚠ **ガードの実装は `ginseng-core` にある (#289)。** 判定そのもののテストは
    # あちらが正本で、ここは**この gem の口に届いていること**を見る。
    #
    # ⚠⚠ **継ぎ目は `HTTParty.public_send`。** `Ginseng::HTTP` の private の分け方は版で
    # 変わるが、ここは変わらない。
    #
    # 🔴🔴 **ガードが効いたかは、HTTParty に渡った `follow_redirects` では見ない
    # (pooza/ginseng-core#655)。** core 6.0.0 から既定の経路もリダイレクトを自前で追うので、
    # HTTParty には**常に** `follow_redirects: false` が渡る。⚠⚠ そのまま見ていると
    # **ガードを外しても緑**になる（実測: core 6.0.0 でガードを挿さなくしても 8 本が緑）。
    # ⚠ 代わりに `follows?` で、302 を返されたときに追ったか（`GatewayError` にならずに済んだか）を見る。
    class RedirectGuardTest < TestCase
      class FakeResponse
        attr_reader :code, :headers, :body

        def initialize(code, location = nil)
          @code = code
          @headers = location ? {'location' => location} : {}
          @body = ''
        end

        # ⚠ `MulukhiyaService#search_hashtags` が応答を読むため。
        def each_value
        end
      end

      METHODS = [:get, :head, :post, :put, :delete].freeze

      # `follows?` のリダイレクト先。
      REDIRECT_TARGET = 'https://elsewhere.example.com/moved'.freeze

      # ⚠ 利用側を模した HTTP。**`RedirectGuard` を知らない**（`Ginseng::HTTP` の子）。
      class ForeignHTTP < Ginseng::HTTP; end

      class ForeignService < MisskeyService
        def http_class
          return ForeignHTTP
        end
      end

      class ForeignMulukhiyaService < MulukhiyaService
        def http_class
          return ForeignHTTP
        end
      end

      def setup
        require 'httparty'
        @code = 200
        @captured = []
        @originals = METHODS.to_h {|method| [method, HTTParty.method(method)]}
        captured = @captured
        owner = self
        METHODS.each do |method|
          HTTParty.define_singleton_method(method) do |uri, options = {}, &_block|
            captured.push([method, uri, options])
            next owner.respond(uri, options)
          end
        end
      end

      def teardown
        super
        @originals.each {|method, impl| HTTParty.define_singleton_method(method, impl)}
      end

      attr_accessor :code

      # ⚠⚠ **`follows?` の中では、1 段目が 302 を返す。** HTTParty に追わせる形（core 5.x の
      # 既定の経路）では、`follow_redirects` が偽でなければ **HTTParty が追い切った**ものとして
      # 200 を返す。自前で追う形（core 6.0.0）では、`Location` の先へ来た 2 回目に 200 を返す。
      # ⚠ どちらの版でも、追わないと決めた要求だけが 302 を受け取り、ガードが `GatewayError` にする。
      def respond(uri, options)
        return FakeResponse.new(code) unless @redirecting
        return FakeResponse.new(200) if uri.to_s == REDIRECT_TARGET
        follow = options.key?(:follow_redirects) ? options[:follow_redirects] : true
        return FakeResponse.new(200) if follow
        return FakeResponse.new(302, REDIRECT_TARGET)
      end

      # 🔴🔴 **本件の芯 (#280)。** 資格情報を持つ要求は追従を切る。
      def test_credentialed_request_does_not_follow_redirects
        follows = follows? do
          create.post('/api/v1/statuses', {
            body: {status: '本文'},
            headers: {'Authorization' => 'Bearer secret'},
          })
        end

        assert_false(follows)
      end

      # 🔴🔴 **本文を伴うメソッドは無条件で切る (#280 Codex P1)。**
      #
      # ⚠⚠ **本文のキーを列挙する形は、口を足すたびに漏れる。** 実際 `i`（Misskey）だけを
      # 見ていた初版は、**認証の口 4 つを素通りさせていた**。
      def test_write_requests_never_follow_redirects
        [
          {body: {text: '本文', i: 'secret'}},                                 # Misskey のトークン
          {body: {'client_secret' => 'secret', 'code' => 'authcode'}},       # Mastodon / Pleroma の OAuth
          {body: {appSecret: 'secret'}},                                     # Misskey のセッション
          {body: {'code_verifier' => 'secret'}},                             # OAuth 2.0 (PKCE)
          {},                                                                # 本文無し
        ].each do |params|
          assert_false(follows? {create.post('/api/auth/session/userkey', params)}, params.inspect)
        end
      end

      # ⚠ `put` / `delete` も同じ。
      def test_other_write_methods_are_guarded
        assert_false(follows? {create.put('/api/v1/statuses/1', {body: {status: '本文'}})})
        assert_false(follows? {create.delete('/api/v1/statuses/1')})
      end

      # ⚠ `basic_auth` / `cookies` はヘッダに現れない（HTTParty が後から移す）。
      def test_credential_options_are_credentials
        assert_false(follows? {create.get('/api/v1/accounts/verify_credentials', {cookies: {session: 'secret'}})})
      end

      # ⚠⚠ **資格情報を持たない要求は追う (#280)。** 🔴 一律に切ると、投稿先が正規に
      # リダイレクトを返す探索の経路（nodeinfo など）が壊れる。
      def test_plain_request_still_follows_redirects
        assert_true(follows? {create.get('/.well-known/nodeinfo')}, '追従を切らないこと')
      end

      # ⚠ 口の側が明示していたら、そちらを優先する。
      def test_explicit_option_wins
        follows = follows? do
          create.post('/api/v1/statuses', {
            body: {status: '本文'},
            headers: {'Authorization' => 'Bearer secret'},
            follow_redirects: true,
          })
        end

        assert_true(follows)
      end

      # 🔴🔴 **3xx を黙って返さない (#282)。** 応答を見ない利用側で「投稿されていないのに
      # 成功」になる。⚠ 上流が例外にするのは 400 以上だけ。
      def test_redirect_is_an_error
        self.code = 302

        error = assert_raise(GatewayError) do
          create.post('/api/v1/statuses', {
            body: {status: '本文'},
            headers: {'Authorization' => 'Bearer secret'},
          })
        end

        assert_equal(302, error.response.code, '応答を添えること')
      end

      # ⚠ **304 はリダイレクトではない。**
      def test_not_modified_is_not_an_error
        self.code = 304

        response = create.get('/api/v1/statuses/1', {headers: {'Authorization' => 'Bearer secret'}})

        assert_equal(304, response.code)
      end

      # ⚠⚠ **添付の口も同じ扱い。** 🔴 multipart の本文ごと撃ち直されうる。
      def test_upload_is_guarded
        follows = follows? do
          create.upload('/api/v1/media', StringIO.new('body'), {
            headers: {'Authorization' => 'Bearer secret'},
          })
        end

        assert_false(follows)
      end

      # 🔴 **口ごとに書く形にしない (#280)。** `MisskeyService#post` は
      # `follow_redirects` を書いていないが、トークンを本文に持つので切れる。
      def test_service_applies_the_guard
        service = MisskeyService.new(Ginseng::URI.parse('https://misskey.example.com/'), 'secret')
        # ⚠ 口の側は `follow_redirects` を書いていない。

        assert_false(follows? {service.post('本文')}, '口の側に書かなくても効くこと')
        assert_equal('secret', JSON.parse(first_options[:body])['i'])
      end

      # 🔴🔴 **利用側が `http_class` を差し替えていても届くこと（リリース前レビューの赤）。**
      #
      # ⚠⚠ **利用側 3 本（mulukhiya / makoto2 / tomato-shrieker）は全員、自前の
      # `HTTP` を返す `http_class` を持っている**（gem 側の `Environment` / `Logger` を
      # 指さないようにするため）。🔴 初版のガードは `Ginseng::HTTP` の**サブクラス**
      # だったので、**継承経路に一度も現れず 1 本も届いていなかった** — 上の
      # `test_service_applies_the_guard` は `MisskeyService` を直に使うので**必ず緑**で、
      # この穴を見つけられない。
      def test_guard_reaches_a_replaced_http_class
        service = ForeignService.new(Ginseng::URI.parse('https://misskey.example.com/'), 'secret')

        assert_instance_of(ForeignHTTP, service.http, '利用側の HTTP が使われていること')
        assert_false(follows? {service.post('本文')}, '差し替えられていても効くこと')
      end

      # 🔴🔴 **挿さっているのは core の module そのもの (#289)。** ⚠⚠ 自前の copy を
      # 持っていた間、「何が資格情報か」の一覧が 2 つあり、core 側だけが増えていた。
      def test_guard_is_the_one_in_core
        assert_same(Ginseng::HTTP::RedirectGuard, RedirectGuard, '名前は alias で残すこと')

        service = ForeignService.new(Ginseng::URI.parse('https://misskey.example.com/'), 'secret')

        assert_includes(service.http.singleton_class.ancestors, Ginseng::HTTP::RedirectGuard)
      end

      # 🔴 **自前の copy が見ていなかった資格情報 (#289)。** 固定の 3 個
      # （`Authorization` / `Cookie` / `Proxy-Authorization`）以外は追従したままだった。
      def test_conventional_credentials_are_guarded_on_the_service
        http = ForeignService.new(Ginseng::URI.parse('https://misskey.example.com/'), 'secret').http

        [
          ['/api/meta', {headers: {'X-Api-Key' => 'secret'}}],
          ['/api/meta', {query: {access_token: 'secret'}}],
          ['/api/meta?access%5Ftoken=secret', {}],
          ['https://user:pass@misskey.example.com/api/meta', {}],
        ].each do |uri, params|
          assert_false(follows? {http.get(uri, params)}, uri + params.inspect)
        end
      end

      # 🔴 **`MulukhiyaService` は `Service` を継承しないので、別に挿す (#320)。** 本文を POST する
      # `search_hashtags` は追わない。資格情報の無い GET（`about` / `health`）は従来どおり追う。
      def test_mulukhiya_service_applies_the_guard
        [MulukhiyaService, ForeignMulukhiyaService].each do |service_class|
          service = service_class.new('https://mulukhiya.example.com/')

          assert_false(follows? {service.search_hashtags('本文')}, service_class.name)
          assert_equal('本文', JSON.parse(first_options[:body])['q'])
          assert_true(follows? {service.about}, service_class.name)
        end
      end

      private

      # ⚠ **`Service` と同じ形で組む** — ガードは継承ではなく prepend で入る。
      def create
        http = Ginseng::HTTP.new.guard_redirects!
        http.base_uri = 'https://mstdn.example.com/'
        return http
      end

      # 直前の `follows?` の 1 段目で HTTParty に渡った options。
      def first_options
        return @captured.first.last
      end

      # 1 段目が 302 を返したときに追ったか。⚠ 追わないと決めた要求は、ガードが `GatewayError` にする
      # （`test_redirect_is_an_error`）。⚠ `@captured` は毎回空にする（本文を見るテストが 1 段目を引く）。
      def follows?
        @captured.clear
        @redirecting = true
        yield
        return true
      rescue GatewayError => e
        raise unless e.response&.code == 302
        return false
      ensure
        @redirecting = false
      end
    end
  end
end
