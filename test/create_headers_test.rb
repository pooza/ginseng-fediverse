module Ginseng
  module Fediverse
    # `Service#create_headers` の契約。
    #
    # ⚠⚠ **眼目は「渡された hash を書き換えないこと」** (#258)。複製せずに
    # 書き込んでいたため、呼び側の hash に `X-Mulukhiya` と、`MastodonService`
    # 系では**設定のトークン**が残っていた。同じ hash を使い回す呼び出しでは、
    # **別ホスト宛の要求にも載りうる**。
    #
    # ⚠ 呼び出しは 3 サービス 38 箇所あり、すべて `create_headers(params[:headers])`
    # の形。**複製は `create_headers` の側に 1 つだけ置く**ことにしたので、
    # ここでは代表 3 クラスで契約を押さえる。
    class CreateHeadersTest < TestCase
      # ⚠ `MastodonService`（`Authorization` を足す）、`PleromaService`
      # （`MastodonService` を継承）、`MisskeyService`（基底のまま）の 3 系統。
      def services
        return [
          MastodonService.new(Ginseng::URI.parse('https://mastodon.example.com/')),
          PleromaService.new(Ginseng::URI.parse('https://pleroma.example.com/')),
          MisskeyService.new(Ginseng::URI.parse('https://misskey.example.com/')),
        ]
      end

      # ⚠⚠ **本丸。**呼び側の hash に何も書き戻さない。
      def test_does_not_mutate_given_headers
        services.each do |service|
          headers = {'X-Trace' => 'abc'}
          service.create_headers(headers)

          assert_equal({'X-Trace' => 'abc'}, headers, service.class.name)
        end
      end

      # 複製を返す（呼び側の hash と同一オブジェクトではない）。
      def test_returns_another_object
        services.each do |service|
          headers = {'X-Trace' => 'abc'}

          assert_not_same(headers, service.create_headers(headers), service.class.name)
        end
      end

      # ⚠ 複製しても、渡した内容は落とさない。
      def test_keeps_given_headers
        services.each do |service|
          assert_equal('abc', service.create_headers({'X-Trace' => 'abc'})['X-Trace'], service.class.name)
        end
      end

      # ⚠ `||=` なので呼び側のトークンが勝つ。潰すと利用者の投稿を設定の
      # トークンで書き換えることになる。
      def test_given_authorization_wins
        services.each do |service|
          headers = service.create_headers({'Authorization' => 'Bearer ゴメちゃん'})

          assert_equal('Bearer ゴメちゃん', headers['Authorization'], service.class.name)
        end
      end

      # 自己申告のヘッダを足す。⚠ モロヘイヤの nginx はこの有無で振り分ける。
      def test_identifies_itself
        services.each do |service|
          assert_predicate(service.create_headers({})['X-Mulukhiya'], :present?, service.class.name)
        end
      end

      # ⚠ 引数なし・nil でも落ちない（呼び出し側は `params[:headers]` を
      # そのまま渡すので、nil が来る経路が実際にある）。
      def test_accepts_nil
        services.each do |service|
          assert_predicate(service.create_headers(nil)['X-Mulukhiya'], :present?, service.class.name)
          assert_predicate(service.create_headers['X-Mulukhiya'], :present?, service.class.name)
        end
      end
    end
  end
end
