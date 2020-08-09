module Ginseng
  module Fediverse
    class MastodonServiceTest < Test::Unit::TestCase
      def setup
        @config = Config.instance
        @mastodon = MastodonService.new(@config['/mastodon/url'], @config['/mastodon/token'])
        @toot_id = @config['/mastodon/test_toot']
      end

      def test_new
        assert_kind_of(MastodonService, @mastodon)
      end

      def test_uri
        assert_kind_of(URI, @mastodon.uri)
      end

      def test_tag_uri
        assert_equal(@mastodon.create_tag_uri('日本語のタグ').path, '/tags/日本語のタグ')
      end

      def test_mulukhiya?
        assert_false(@mastodon.mulukhiya?)
        assert_false(@mastodon.mulukhiya_enable?)
        @mastodon.mulukhiya_enable = true
        assert(@mastodon.mulukhiya?)
        assert(@mastodon.mulukhiya_enable?)
        @mastodon.mulukhiya_enable = false
      end

      def test_toot
        return if Environment.ci?
        r = @mastodon.toot('文字列からトゥート')
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['content'], '<p>文字列からトゥート</p>')

        r = @mastodon.toot(status: 'ハッシュからプライベートなトゥート', visibility: 'private')
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['content'], '<p>ハッシュからプライベートなトゥート</p>')
        assert_equal(r['visibility'], 'private')
      end

      def test_upload
        return if Environment.ci?
        assert(@mastodon.upload(File.join(Environment.dir, 'images/pooza.jpg'), {response: :id}).positive?)
      end

      def test_favourite
        return if Environment.ci?
        assert_equal(@mastodon.favourite(@toot_id).code, 200)
      end

      def test_reblog
        return if Environment.ci?
        assert_equal(@mastodon.reblog(@toot_id).code, 200)
      end

      def test_announcements
        return if Environment.ci?
        assert_kind_of(Array, @mastodon.announcements)
        @mastodon.announcements do |announcement|
          assert_kind_of(Hash, accouncement)
          assert(accouncement['id'].present?)
          assert(accouncement['title'].present?)
        end
      end

      def test_nodeinfo
        info = @mastodon.nodeinfo
        assert_kind_of(String, info['metadata']['nodeName'])
        assert_kind_of(String, info['metadata']['maintainer']['name'])
        assert_kind_of(String, info['metadata']['maintainer']['email'])
      end

      def test_statuses
        return if Environment.ci?
        assert_kind_of(Array, @mastodon.statuses)
      end

      def test_followers
        return if Environment.ci?
        assert_equal(@mastodon.followers.code, 200)
      end

      def test_followees
        return if Environment.ci?
        assert_equal(@mastodon.followees.code, 200)
      end

      def test_search
        return if Environment.ci?
        assert_equal(@mastodon.search('pooza').code, 200)
        assert_equal(@mastodon.search('pooza', {version: 2}).code, 200)
      end

      def test_upload_remote_resource
        return if Environment.ci?
        assert(@mastodon.upload_remote_resource('https://www.b-shock.co.jp/images/ota-m.gif', {response: :id}).positive?)
      end

      def test_create_tag
        assert_equal(MastodonService.create_tag('宮本佳那子'), '#宮本佳那子')
        assert_equal(MastodonService.create_tag('宮本 佳那子'), '#宮本_佳那子')
        assert_equal(MastodonService.create_tag('宮本 佳那子 '), '#宮本_佳那子')
        assert_equal(MastodonService.create_tag('#宮本 佳那子 '), '#宮本_佳那子')
      end
    end
  end
end
