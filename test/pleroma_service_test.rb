module Ginseng
  module Fediverse
    class PleromaServiceTest < Test::Unit::TestCase
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
        return if Environment.ci?
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

      def test_nodeinfo
        info = @pleroma.nodeinfo
        assert_kind_of(String, info['metadata']['nodeName'])
        assert_kind_of(String, info['metadata']['maintainer']['name'])
        assert_kind_of(String, info['metadata']['maintainer']['email'])
      end

      def test_statuses
        return if Environment.ci?
        assert_kind_of(Array, @pleroma.statuses(account_id: @config['/pleroma/account/id']))
      end

      def test_upload
        return if Environment.ci?
        assert(@pleroma.upload(File.join(Environment.dir, 'images/pooza.jpg'), {response: :id}).positive?)
      end

      def test_upload_remote_resource
        return if Environment.ci?
        assert(@pleroma.upload_remote_resource('https://www.b-shock.co.jp/images/ota-m.gif', {response: :id}).positive?)
      end

      def test_create_tag
        assert_equal(PleromaService.create_tag('宮本佳那子'), '#宮本佳那子')
        assert_equal(PleromaService.create_tag('宮本 佳那子'), '#宮本_佳那子')
        assert_equal(PleromaService.create_tag('宮本 佳那子 '), '#宮本_佳那子')
        assert_equal(PleromaService.create_tag('#宮本 佳那子 '), '#宮本_佳那子')
      end
    end
  end
end
