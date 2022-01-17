module Ginseng
  module Fediverse
    class PleromaServiceTest < TestCase
      def setup
        @config = Config.instance
        @service = PleromaService.new(@config['/pleroma/url'], @config['/pleroma/token'])
      end

      def test_new
        assert_kind_of(PleromaService, @service)
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

      def test_toot
        r = @service.toot('文字列からトゥート')
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['content'], '文字列からトゥート')

        r = @service.toot(status: 'ハッシュからプライベートなトゥート', visibility: 'private')
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['content'], 'ハッシュからプライベートなトゥート')
        assert_equal(r['visibility'], 'private')
      end

      def test_delete_status
        id = @service.toot('このあと削除するトゥート')['id']
        r = @service.delete_status(id)
        assert_equal(r.code, 200)
        assert_equal(r['text'], 'このあと削除するトゥート')
      end

      def test_announcements
        assert_nil(@service.announcements)
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
        assert_kind_of(Array, @service.statuses(account_id: @config['/pleroma/account/id']))
      end

      def test_upload
        assert_kind_of(String, @service.upload(File.join(Environment.dir, 'images/pooza.jpg'), {response: :id}))
      end

      def test_upload_remote_resource
        assert_kind_of(String, @service.upload_remote_resource('https://www.b-shock.co.jp/images/ota-m.gif', {response: :id}))
      end

      def test_create_parser
        assert_kind_of(TootParser, @service.create_parser(''))
      end

      def test_max_post_text_length
        assert(@service.max_post_text_length.positive?)
      end

      def test_characters_reserved_per_url
        assert(@service.characters_reserved_per_url.positive?)
      end

      def test_max_media_attachments
        assert(@service.max_media_attachments.positive?)
      end
    end
  end
end
