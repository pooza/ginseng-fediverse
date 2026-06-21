module Ginseng
  module Fediverse
    class TootURITest < TestCase
      # parser/toot/url/patterns の各形式から toot_id を抽出できることを確認する。
      # 末尾の numeric_ap_id 形式 (/ap/users/<id>/statuses/<id>) は現代 Mastodon の
      # 既定 (#241)。
      def test_toot_id
        {
          'https://mstdn.example.com/web/statuses/123' => 123,
          'https://mstdn.example.com/@pooza/456' => 456,
          'https://mstdn.example.com/users/pooza/statuses/789' => 789,
          'https://mstdn.example.com/ap/users/116701601341929545/statuses/116701682233818969' =>
            116_701_682_233_818_969,
        }.each do |url, id|
          uri = TootURI.parse(url)

          assert_equal(id, uri.toot_id, url)
          assert_predicate(uri, :valid?, url)
        end
      end

      def test_toot_id_unmatched
        uri = TootURI.parse('https://mstdn.example.com/about/more')

        assert_nil(uri.toot_id)
        assert_false(uri.valid?)
      end
    end
  end
end
