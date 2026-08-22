module Ginseng
  module Fediverse
    # ALT 編集 (`PUT /api/v1/statuses/:id`) で上流へ送る body。
    #
    # 眼目は 2 つある。
    #
    # 1. **media_attributes が Hash の配列のまま届くこと**
    #    (pooza/mulukhiya-toot-proxy#4621)。form-urlencoded へ畳んで
    #    `media_attributes[0][id]` と数字の添字にすると、Rails 側では
    #    `fields_for` 形式の Hash `{"0" => {...}}` になり配列にならない。
    #    Mastodon の `UpdateStatusService` はそれを each して `["0", {...}]`
    #    という Array を掴み、`attributes[:id]` で **500** になる。
    # 2. **media_attributes 以外のキーを落とさないこと**
    #    (pooza/mulukhiya-toot-proxy#4589)。Mastodon は「送らなかった
    #    パラメータ」を現状維持ではなく「空で更新」として扱うため、落とすと
    #    ALT を 1 つ直すだけで **投稿から添付が全部外れ、CW と閲覧注意が消える**。
    class MastodonServiceUpdateStatusTest < TestCase
      # PUT の引数を捕まえるだけの http スタブ。
      class CapturingHTTP
        attr_reader :uri, :options

        def put(uri, options = {})
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

      def update(body, params = {})
        @service.update_status('111', body, params)
        return @http.options
      end

      # ginseng-core の `create_body` が実際に送出する形（Content-Type が
      # JSON なら `to_json`）まで通して、上流が受け取るものを見る。
      def sent_body(options)
        return JSON.parse(options[:body].to_json)
      end

      # ⚠ **本丸その 2。**モロヘイヤは上流 Mastodon の前に立つプロキシで、
      # nginx は `X-Mulukhiya` の有無で「モロヘイヤへ通す／素通しする」を
      # 振り分ける。名乗らずに出ると**自分自身へ送り返される**
      # (pooza/mulukhiya-toot-proxy#4621・ステージング実機で 405 / ループ)。
      def test_service_identifies_itself
        options = update({media_attributes: [{id: '1'}]})

        assert_predicate(options[:headers]['X-Mulukhiya'], :present?)
      end

      # media_attributes を伴わない更新でも名乗ること。
      def test_service_identifies_itself_without_media_attributes
        options = update({status: '本文'})

        assert_predicate(options[:headers]['X-Mulukhiya'], :present?)
      end

      # ⚠ **呼び側のトークンを上書きしない。**`create_headers` の
      # `Authorization` は `||=`。潰すと利用者の投稿を設定のトークンで
      # 書き換えることになる。
      def test_given_authorization_wins
        options = update(
          {media_attributes: [{id: '1'}]},
          {headers: {'Authorization' => 'Bearer ゴメちゃん'}},
        )

        assert_equal('Bearer ゴメちゃん', options[:headers]['Authorization'])
      end

      # 渡されなければ設定のトークンで名乗る。
      def test_authorization_falls_back_to_config
        options = update({media_attributes: [{id: '1'}]})

        assert_predicate(options[:headers]['Authorization'], :present?)
      end

      # ⚠⚠ **渡された hash を書き換えない (#256)。** `create_headers` は
      # `Authorization` と `X-Mulukhiya` を渡された hash そのものへ書き込むので、
      # 複製しないと**設定のトークンが呼び側に残る**。
      def test_does_not_mutate_given_headers
        headers = {'X-Trace' => 'abc'}
        update({media_attributes: [{id: '1'}]}, {headers:})

        assert_equal({'X-Trace' => 'abc'}, headers)
      end

      def test_content_type_is_json
        options = update({media_attributes: [{id: '1', description: 'ゴメちゃん'}]})

        assert_equal('application/json', options[:headers]['Content-Type'])
      end

      # ⚠ **本丸。** Hash の配列であること。数字の添字で畳むと Rails 側で
      # Hash になり、Mastodon が 500 を返す。
      def test_media_attributes_are_sent_as_array_of_hashes
        options = update({
          media_attributes: [
            {id: '1', description: 'ゴメちゃん'},
            {id: '2', description: 'ダイの大冒険'},
          ],
        })

        assert_equal(
          [
            {'id' => '1', 'description' => 'ゴメちゃん'},
            {'id' => '2', 'description' => 'ダイの大冒険'},
          ],
          sent_body(options)['media_attributes'],
        )
      end

      # ⚠ **平坦化された痕跡が残っていないこと。**`media_attributes[0][id]` が
      # 生きていると、キーとしては通っても Rails 側で配列にならない。
      def test_flattened_keys_are_gone
        options = update({media_attributes: [{id: '1'}]})

        refute_includes(options[:body].to_json, 'media_attributes[0]')
      end

      def test_status_is_kept
        options = update({status: '本文', media_attributes: [{id: '1'}]})

        assert_equal('本文', sent_body(options)['status'])
      end

      # 添付が外れないために必須 (#4589)。
      def test_media_ids_survive_as_array
        options = update({media_ids: ['1', '2'], media_attributes: [{id: '1'}]})

        assert_equal(['1', '2'], sent_body(options)['media_ids'])
      end

      # CW を消さないために必須 (#4589)。
      def test_spoiler_text_survives
        options = update({spoiler_text: 'ネタバレ', media_attributes: [{id: '1'}]})

        assert_equal('ネタバレ', sent_body(options)['spoiler_text'])
      end

      # ⚠ false は「送らない」ではない。落とすと閲覧注意が意図せず外れる／付く。
      def test_false_survives
        options = update({sensitive: false, media_attributes: [{id: '1'}]})

        body = sent_body(options)
        # ⚠ refute だけだと nil でも通る。キーの存在と対で見る。
        refute(body['sensitive'])
        assert(body.key?('sensitive'))
      end

      def test_nil_is_dropped
        options = update({status: nil, media_attributes: [{id: '1'}]})

        refute(sent_body(options).key?('status'))
      end

      # 呼び側が渡したヘッダ（Authorization 等）を潰さないこと。
      def test_given_headers_survive
        options = update(
          {media_attributes: [{id: '1'}]},
          {headers: {'Idempotency-Key' => 'ゴメちゃん'}},
        )

        assert_equal('ゴメちゃん', options[:headers]['Idempotency-Key'])
      end

      # ⚠⚠ **この行の本来の効き目。**ginseng-core の `create_headers` は
      # `Content-Type ||= 'application/json'` なので、無指定なら放っておいても
      # JSON になる。潰さねばならないのは **呼び出し側が非 JSON の Content-Type
      # を渡してくる場合**で、`||=` ではそれが残り 500 に戻る。mulukhiya は
      # 受信ヘッダをそのまま渡すので、これは実在する経路。
      def test_content_type_overrides_the_caller_s_one
        options = update(
          {media_attributes: [{id: '1'}]},
          {headers: {'Content-Type' => 'application/x-www-form-urlencoded'}},
        )

        assert_equal('application/json', options[:headers]['Content-Type'])
      end

      # media_attributes を伴わない更新（本文だけの送り直し）は従来どおり。
      # ⚠ ここで Content-Type を立てると、無関係な経路の送出まで変わる。
      def test_content_type_is_untouched_without_media_attributes
        options = update({status: '本文'})

        assert_nil(options[:headers]['Content-Type'])
      end

      def test_string_body_is_treated_as_status
        options = update('本文')

        assert_equal('本文', options[:body][:status])
      end
    end
  end
end
