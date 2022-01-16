module Ginseng
  module Fediverse
    class PleromaServiceTest < TestCase
      def setup
        @config = Config.instance
        @pleroma = PleromaService.new(@config['/pleroma/url'], @config['/pleroma/token'])
      end

      def test_new
        assert_kind_of(PleromaService, @pleroma)
      end

      def test_uri
        assert_kind_of(URI, @pleroma.uri)
      end

      def test_tag_uri
        assert_equal(@pleroma.create_tag_uri('日本語のタグ').path, '/tags/日本語のタグ')
      end

      def test_mulukhiya?
        assert_false(@pleroma.mulukhiya?)
        assert_false(@pleroma.mulukhiya_enable?)
        @pleroma.mulukhiya_enable = true
        assert(@pleroma.mulukhiya?)
        assert(@pleroma.mulukhiya_enable?)
        @pleroma.mulukhiya_enable = false
      end

      def test_toot
        r = @pleroma.toot('文字列からトゥート')
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['content'], '文字列からトゥート')

        r = @pleroma.toot(status: 'ハッシュからプライベートなトゥート', visibility: 'private')
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['content'], 'ハッシュからプライベートなトゥート')
        assert_equal(r['visibility'], 'private')
      end

      def test_delete_status
        id = @pleroma.toot('このあと削除するトゥート')['id']
        r = @pleroma.delete_status(id)
        assert_equal(r.code, 200)
        assert_equal(r['text'], 'このあと削除するトゥート')
      end

      def test_announcements
        assert_nil(@pleroma.announcements)
      end

      def test_nodeinfo
        info = @pleroma.nodeinfo
        assert_kind_of(String, info['metadata']['nodeName'])
        assert_kind_of(String, info['metadata']['maintainer']['name'])
        assert_kind_of(String, info['metadata']['maintainer']['email'])
      end

      def test_node_name
        assert_kind_of(String, @pleroma.node_name)
      end

      def test_maintainer_name
        assert_kind_of(String, @pleroma.maintainer_name)
      end

      def test_maintainer_email
        assert_kind_of(String, @pleroma.maintainer_email)
      end

      def test_statuses
        assert_kind_of(Array, @pleroma.statuses(account_id: @config['/pleroma/account/id']))
      end

      def test_upload
        assert_kind_of(String, @pleroma.upload(File.join(Environment.dir, 'images/pooza.jpg'), {response: :id}))
      end

      def test_upload_remote_resource
        assert_kind_of(String, @pleroma.upload_remote_resource('https://www.b-shock.co.jp/images/ota-m.gif', {response: :id}))
      end

      def test_max_post_text_length
        assert(@pleroma.max_post_text_length.positive?)
      end

      def test_characters_reserved_per_url
        assert(@pleroma.characters_reserved_per_url.positive?)
      end

      def test_max_media_attachments
        assert(@pleroma.max_media_attachments.positive?)
      end
    end
  end
end
