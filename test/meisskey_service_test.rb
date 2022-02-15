module Ginseng
  module Fediverse
    class MeisskeyServiceTest < TestCase
      def setup
        @config = Config.instance
        @service = MeisskeyService.new(@config['/meisskey/url'], @config['/meisskey/token'])
      end

      def test_new
        assert_kind_of(MeisskeyService, @service)
      end

      def test_uri
        assert_kind_of(URI, @service.uri)
      end

      def test_tag_uri
        assert_equal(@service.create_tag_uri('日本語のタグ').path, '/tags/日本語のタグ')
      end

      def test_mulukhiya?
        assert_false(@service.mulukhiya?)
        assert_false(@service.mulukhiya_enable?)
        @service.mulukhiya_enable = true
        assert(@service.mulukhiya?)
        assert(@service.mulukhiya_enable?)
        @service.mulukhiya_enable = false
      end

      def test_note
        r = @service.note('文字列からノート')
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['createdNote']['text'], '文字列からノート')
      end

      def test_delete_status
        id = @service.note('このあと削除するトゥート')['createdNote']['id']
        r = @service.delete_status(id)
        assert_equal(r.code, 204)
      end

      def test_announcements
        assert_kind_of(Array, @service.announcements)
        @service.announcements do |announcement|
          assert_kind_of(Hash, announcement)
          assert(announcement['id'].present?)
          assert(announcement['title'].present?)
        end
      end

      def test_nodeinfo
        info = @service.nodeinfo
        assert_kind_of(String, info['metadata']['nodeName'])
        assert_kind_of(String, info['metadata']['maintainer']['name'])
        assert_kind_of(String, info['metadata']['maintainer']['email'])
      end

      def test_node_name
        assert_kind_of(String, @service.node_name)
      end

      def test_maintainer_name
        assert_kind_of(String, @service.maintainer_name)
      end

      def test_maintainer_email
        assert_kind_of(String, @service.maintainer_email)
      end

      def test_statuses
        assert_kind_of(Array, @service.statuses(account_id: @config['/meisskey/account/id']))
      end

      def test_upload
        assert_kind_of(RestClient::Response, @service.upload(File.join(Environment.dir, 'images/pooza.jpg')))
      end

      def test_upload_remote_resource
        assert_kind_of(RestClient::Response, @service.upload_remote_resource('https://www.b-shock.co.jp/images/ota-m.gif'))
      end

      def test_create_parser
        assert_kind_of(NoteParser, @service.create_parser(''))
      end

      def test_max_post_text_length
        assert(@service.max_post_text_length.positive?)
      end

      def test_max_media_attachments
        assert(@service.max_media_attachments.positive?)
      end

      def test_characters_reserved_per_url
        assert(@service.characters_reserved_per_url.positive?)
      end

      def test_delete_attachment
        response = @service.upload(File.join(Environment.dir, 'images/pooza.jpg'))
        id = JSON.parse(response.body)['id']
        r = @service.delete_attachment(id)
        assert_equal(r.code, 204)
      end
    end
  end
end
