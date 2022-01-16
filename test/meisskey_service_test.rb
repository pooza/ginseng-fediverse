module Ginseng
  module Fediverse
    class MeisskeyServiceTest < TestCase
      def setup
        @config = Config.instance
        @meisskey = MeisskeyService.new(@config['/meisskey/url'], @config['/meisskey/token'])
      end

      def test_new
        assert_kind_of(MeisskeyService, @meisskey)
      end

      def test_uri
        assert_kind_of(URI, @meisskey.uri)
      end

      def test_tag_uri
        assert_equal(@meisskey.create_tag_uri('日本語のタグ').path, '/tags/日本語のタグ')
      end

      def test_mulukhiya?
        assert_false(@meisskey.mulukhiya?)
        assert_false(@meisskey.mulukhiya_enable?)
        @meisskey.mulukhiya_enable = true
        assert(@meisskey.mulukhiya?)
        assert(@meisskey.mulukhiya_enable?)
        @meisskey.mulukhiya_enable = false
      end

      def test_note
        r = @meisskey.note('文字列からノート')
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['createdNote']['text'], '文字列からノート')
      end

      def test_delete_status
        id = @meisskey.note('このあと削除するトゥート')['createdNote']['id']
        r = @meisskey.delete_status(id)
        assert_equal(r.code, 204)
      end

      def test_announcements
        assert_kind_of(Array, @meisskey.announcements)
        @meisskey.announcements do |announcement|
          assert_kind_of(Hash, accouncement)
          assert(accouncement['id'].present?)
          assert(accouncement['title'].present?)
        end
      end

      def test_nodeinfo
        info = @meisskey.nodeinfo
        assert_kind_of(String, info['metadata']['nodeName'])
        assert_kind_of(String, info['metadata']['maintainer']['name'])
        assert_kind_of(String, info['metadata']['maintainer']['email'])
      end

      def test_node_name
        assert_kind_of(String, @meisskey.node_name)
      end

      def test_maintainer_name
        assert_kind_of(String, @meisskey.maintainer_name)
      end

      def test_maintainer_email
        assert_kind_of(String, @meisskey.maintainer_email)
      end

      def test_statuses
        assert_kind_of(Array, @meisskey.statuses(account_id: @config['/meisskey/account/id']))
      end

      def test_upload
        assert_kind_of(RestClient::Response, @meisskey.upload(File.join(Environment.dir, 'images/pooza.jpg')))
      end

      def test_upload_remote_resource
        assert_kind_of(RestClient::Response, @meisskey.upload_remote_resource('https://www.b-shock.co.jp/images/ota-m.gif'))
      end

      def test_max_post_text_length
        assert(@meisskey.max_post_text_length.positive?)
      end

      def test_delete_attachment
        response = @meisskey.upload(File.join(Environment.dir, 'images/pooza.jpg'))
        id = JSON.parse(response.body)['id']
        r = @meisskey.delete_attachment(id)
        assert_equal(r.code, 204)
      end
    end
  end
end
