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

      def test_account_id
        {
          'https://mstdn.example.com/users/pooza/statuses/789' => 'pooza',
          'https://mstdn.example.com/ap/users/116701601341929545/statuses/116701682233818969' =>
            '116701601341929545',
          'https://mstdn.example.com/@pooza/456' => nil,
        }.each do |url, id|
          assert_equal(id, TootURI.parse(url).account_id, url)
        end
      end

      # publicize! が `/@<username>/<id>` を作れるのは username が分かる形式だけ。
      def test_publicize
        uri = TootURI.parse('https://mstdn.example.com/users/pooza/statuses/789').publicize

        assert_equal('/@pooza/789', uri.path)
      end

      # numeric_ap_id 形式は no-op。`/@<数値 ID>/` という誤った公開 URL を作らない (#243)。
      def test_publicize_leaves_numeric_ap_id_untouched
        url = 'https://mstdn.example.com/ap/users/116701601341929545/statuses/116701682233818969'
        uri = TootURI.parse(url).publicize

        assert_equal('/ap/users/116701601341929545/statuses/116701682233818969', uri.path)
        assert_nil(uri.account_username)
      end

      def test_toot_id_unmatched
        uri = TootURI.parse('https://mstdn.example.com/about/more')

        assert_nil(uri.toot_id)
        assert_false(uri.valid?)
      end

      # 🔴 **数字だけの username を numeric AP ID と取り違えていた (#251)。**
      #
      # `/users/123/statuses/456` は Mastodon で有効な形で、`/@123/456` へ
      # 書き換えられるべきもの。⚠ 値の見た目（数字だけかどうか）で判定して
      # いたため `account_username` が nil を返し、**publicize が黙って
      # no-op になっていた**（#243 以前は書き換えられていた）。
      def test_publicize_numeric_username
        uri = TootURI.parse('https://mstdn.example.com/users/123/statuses/456').publicize

        assert_equal('/@123/456', uri.path)
      end

      def test_account_username_numeric
        uri = TootURI.parse('https://mstdn.example.com/users/123/statuses/456')

        assert_equal('123', uri.account_id)
        assert_equal('123', uri.account_username)
      end

      # ⚠ 一方 `/ap/users/` 由来は**数値 AP ID のまま**。見た目が同じでも
      # 種別が違うので、こちらは username を名乗らせない。
      def test_account_username_by_pattern_not_by_shape
        {
          'https://mstdn.example.com/users/123/statuses/456' => '123',
          'https://mstdn.example.com/ap/users/123/statuses/456' => nil,
        }.each do |url, username|
          assert_equal(username, TootURI.parse(url).account_username, url)
        end
      end
    end
  end
end
