module Ginseng
  module Fediverse
    class MisskeyServiceTest < Ginseng::TestCase
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
      end

      def test_announcements
        assert_kind_of(Array, @misskey.announcements)
        @misskey.announcements do |announcement|
          assert_kind_of(Hash, accouncement)
          assert(accouncement['id'].present?)
          assert(accouncement['title'].present?)
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
        assert(@misskey.upload(File.join(Environment.dir, 'images/pooza.jpg')).present?)
      end

      def test_upload_remote_resource
        assert(@misskey.upload_remote_resource('https://www.b-shock.co.jp/images/ota-m.gif').present?)
      end
    end
  end
end
