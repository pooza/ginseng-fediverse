module Ginseng
  module Fediverse
    class MisskeyServiceTest < TestCase
      def setup
        @config = Config.instance
        @misskey = MisskeyService.new(@config['/misskey/url'], @config['/misskey/token'])
      end

      def test_new
        assert_kind_of(MisskeyService, @misskey)
      end

      def test_uri
        assert_kind_of(URI, @misskey.uri)
      end

      def test_tag_uri
        assert_equal(@misskey.create_tag_uri('日本語のタグ').path, '/tags/日本語のタグ')
      end

      def test_mulukhiya?
        assert_false(@misskey.mulukhiya?)
        assert_false(@misskey.mulukhiya_enable?)
        @misskey.mulukhiya_enable = true
        assert(@misskey.mulukhiya?)
        assert(@misskey.mulukhiya_enable?)
        @misskey.mulukhiya_enable = false
      end

      def test_note
        r = @misskey.note('文字列からノート')
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['createdNote']['text'], '文字列からノート')

        body = {text: 'HashWithIndifferentAccessからノート'}.with_indifferent_access
        r = @misskey.note(body)
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['createdNote']['text'], 'HashWithIndifferentAccessからノート')
      end

      def test_delete_status
        id = @misskey.note('このあと削除するトゥート')['createdNote']['id']
        r = @misskey.delete_status(id)
        assert_equal(r.code, 204)
      end

      def test_announcements
        assert_kind_of(Array, @misskey.announcements)
        @misskey.announcements do |announcement|
          assert_kind_of(Hash, accouncement)
          assert(accouncement['id'].present?)
          assert(accouncement['title'].present?)
        end
      end

      def test_antennas
        assert_kind_of(Array, @misskey.antennas)
        @misskey.antennas do |antenna|
          assert_kind_of(Hash, antenna)
          assert(antenna['id'].present?)
          assert(antenna['title'].present?)
        end
      end

      def test_nodeinfo
        info = @misskey.nodeinfo
        assert_kind_of(String, info['metadata']['nodeName'])
        assert_kind_of(String, info['metadata']['maintainer']['name'])
        assert_kind_of(String, info['metadata']['maintainer']['email'])
      end

      def test_statuses
        assert_kind_of(Array, @misskey.statuses(account_id: @config['/misskey/account/id']))
      end

      def test_upload
        assert_kind_of(RestClient::Response, @misskey.upload(File.join(Environment.dir, 'images/pooza.jpg')))
      end

      def test_upload_remote_resource
        assert_kind_of(RestClient::Response, @misskey.upload_remote_resource('https://www.b-shock.co.jp/images/ota-m.gif'))
      end

      def test_delete_attachment
        response = @misskey.upload(File.join(Environment.dir, 'images/pooza.jpg'))
        id = JSON.parse(response.body)['id']
        r = @misskey.delete_attachment(id)
        assert_equal(r.code, 204)
      end

      def test_search_dupllicated_attachment
        response = @misskey.upload(File.join(Environment.dir, 'images/pooza.jpg'))
        md5 = JSON.parse(response.body)['md5']
        r = @misskey.search_dupllicated_attachment(md5)
        assert_equal(r.parsed_response.first['md5'], md5)
      end
    end
  end
end
