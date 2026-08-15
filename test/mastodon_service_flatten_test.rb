module Ginseng
  module Fediverse
    # ALT 編集 (`PUT /api/v1/statuses/:id`) の body 平坦化。
    #
    # 眼目は **media_attributes 以外のキーを落とさないこと**。Mastodon の
    # `UpdateStatusService` は「送らなかったパラメータ」を現状維持ではなく
    # 「空で更新」として扱うため、ここで落とすと **ALT を 1 つ直すだけで投稿から
    # 添付が全部外れ、CW と閲覧注意フラグが消える**（mulukhiya #4589）。
    class MastodonServiceFlattenTest < TestCase
      def flatten(body)
        service = MastodonService.new(Ginseng::URI.parse('https://mstdn.example.com/'))
        return service.send(:flatten_media_attributes, body)
      end

      def test_media_attributes_are_indexed
        flat = flatten({
          media_attributes: [
            {id: '1', description: 'ゴメちゃん'},
            {id: '2', description: 'ダイの大冒険'},
          ],
        })

        assert_equal('1', flat['media_attributes[0][id]'])
        assert_equal('ゴメちゃん', flat['media_attributes[0][description]'])
        assert_equal('2', flat['media_attributes[1][id]'])
        assert_equal('ダイの大冒険', flat['media_attributes[1][description]'])
      end

      def test_status_is_kept
        flat = flatten({status: '本文', media_attributes: [{id: '1'}]})

        assert_equal('本文', flat['status'])
      end

      # 添付が外れないために必須。配列は `key[]` に置き、
      # URI.encode_www_form が `media_ids[]=1&media_ids[]=2` へ展開する。
      def test_media_ids_survive_as_array
        flat = flatten({media_ids: ['1', '2'], media_attributes: [{id: '1'}]})

        assert_equal(['1', '2'], flat['media_ids[]'])
        assert_equal(
          'media_ids%5B%5D=1&media_ids%5B%5D=2&media_attributes%5B0%5D%5Bid%5D=1',
          ::URI.encode_www_form(flat),
        )
      end

      # CW を消さないために必須。
      def test_spoiler_text_survives
        flat = flatten({spoiler_text: 'ネタバレ', media_attributes: [{id: '1'}]})

        assert_equal('ネタバレ', flat['spoiler_text'])
      end

      # ⚠ false は「送らない」ではない。落とすと閲覧注意が意図せず外れる／付く。
      def test_false_survives
        flat = flatten({sensitive: false, media_attributes: [{id: '1'}]})

        # ⚠ refute だけだと nil でも通る。キーの存在と対で見る。
        refute(flat['sensitive'])
        assert(flat.key?('sensitive'))
      end

      def test_nil_is_dropped
        flat = flatten({status: nil, media_attributes: [{id: '1'}]})

        refute(flat.key?('status'))
      end
    end
  end
end
