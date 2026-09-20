module Ginseng
  module Fediverse
    # 投稿先へ出す要求のリダイレクトの扱い (#280 / #282)。
    #
    # ⚠⚠ **継ぎ目は `HTTParty.public_send`。** `Ginseng::HTTP` の private の分け方は版で
    # 変わる（lock の 1.17 と main の 1.23 で違う）が、ここは両方に在る。
    class RedirectGuardTest < TestCase
      class FakeResponse
        attr_reader :code, :headers, :body

        def initialize(code)
          @code = code
          @headers = {}
          @body = ''
        end
      end

      METHODS = [:get, :head, :post, :put, :delete].freeze

      # ⚠ 利用側を模した HTTP。**`RedirectGuard` を知らない**（`Ginseng::HTTP` の子）。
      class ForeignHTTP < Ginseng::HTTP; end

      class ForeignService < MisskeyService
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
            next FakeResponse.new(owner.code)
          end
        end
      end

      def teardown
        super
        @originals.each {|method, impl| HTTParty.define_singleton_method(method, impl)}
      end

      attr_accessor :code

      # 🔴🔴 **本件の芯 (#280)。** 資格情報を持つ要求は追従を切る。
      def test_credentialed_request_does_not_follow_redirects
        create.post('/api/v1/statuses', {
          body: {status: '本文'},
          headers: {'Authorization' => 'Bearer secret'},
        })

        assert_false(options[:follow_redirects])
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
          create.post('/api/auth/session/userkey', params)

          assert_false(options[:follow_redirects], params.inspect)
        end
      end

      # ⚠ `put` / `delete` も同じ。
      def test_other_write_methods_are_guarded
        create.put('/api/v1/statuses/1', {body: {status: '本文'}})

        assert_false(options[:follow_redirects])

        create.delete('/api/v1/statuses/1')

        assert_false(options[:follow_redirects])
      end

      # ⚠ `basic_auth` / `cookies` はヘッダに現れない（HTTParty が後から移す）。
      def test_credential_options_are_credentials
        create.get('/api/v1/accounts/verify_credentials', {cookies: {session: 'secret'}})

        assert_false(options[:follow_redirects])
      end

      # ⚠⚠ **資格情報を持たない要求は追う (#280)。** 🔴 一律に切ると、投稿先が正規に
      # リダイレクトを返す探索の経路（nodeinfo など）が壊れる。
      def test_plain_request_still_follows_redirects
        create.get('/.well-known/nodeinfo')

        assert_not_equal(false, options[:follow_redirects], '追従を切らないこと')
      end

      # ⚠ 口の側が明示していたら、そちらを優先する。
      def test_explicit_option_wins
        create.post('/api/v1/statuses', {
          body: {status: '本文'},
          headers: {'Authorization' => 'Bearer secret'},
          follow_redirects: true,
        })

        assert_true(options[:follow_redirects])
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
        create.upload('/api/v1/media', StringIO.new('body'), {
          headers: {'Authorization' => 'Bearer secret'},
        })

        assert_false(options[:follow_redirects])
      end

      # 🔴 **口ごとに書く形にしない (#280)。** `MisskeyService#post` は
      # `follow_redirects` を書いていないが、トークンを本文に持つので切れる。
      def test_service_applies_the_guard
        MisskeyService.new(Ginseng::URI.parse('https://misskey.example.com/'), 'secret').post('本文')
        # ⚠ 口の側は `follow_redirects` を書いていない。

        assert_false(options[:follow_redirects], '口の側に書かなくても効くこと')
        assert_equal('secret', JSON.parse(options[:body])['i'])
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

        service.post('本文')

        assert_false(options[:follow_redirects], '差し替えられていても効くこと')
      end

      private

      # ⚠ **`Service` と同じ形で組む** — ガードは継承ではなく prepend で入る。
      def create
        http = Ginseng::HTTP.new
        http.singleton_class.prepend(RedirectGuard)
        http.base_uri = 'https://mstdn.example.com/'
        return http
      end

      def options
        return @captured.last.last
      end
    end
  end
end
