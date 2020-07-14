module Ginseng
  module Fediverse
    class MisskeyServiceTest < Test::Unit::TestCase
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

      def test_mulukhiya?
        assert_false(@misskey.mulukhiya?)
        assert_false(@misskey.mulukhiya_enable?)
        @misskey.mulukhiya_enable = true
        assert(@misskey.mulukhiya?)
        assert(@misskey.mulukhiya_enable?)
        @misskey.mulukhiya_enable = false
      end

      def test_note
        return if Environment.ci?
        r = @misskey.note('文字列からノート')
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['createdNote']['text'], '文字列からノート')
      end

      def test_announcements
        return if Environment.ci?
        assert_kind_of(Array, @misskey.announcements)
      end

      def test_statuses
        return if Environment.ci?
        assert_kind_of(Array, @misskey.statuses(account_id: @config['/misskey/account/id']))
      end

      def test_upload
        return if Environment.ci?
        assert(@misskey.upload(File.join(Environment.dir, 'images/pooza.png')).present?)
      end

      def test_upload_remote_resource
        return if Environment.ci?
        assert(@misskey.upload_remote_resource('https://www.b-shock.co.jp/images/ota-m.gif').present?)
      end

      def test_create_tag
        assert_equal(MisskeyService.create_tag('宮本佳那子'), '#宮本佳那子')
        assert_equal(MisskeyService.create_tag('宮本 佳那子'), '#宮本_佳那子')
        assert_equal(MisskeyService.create_tag('宮本 佳那子 '), '#宮本_佳那子')
        assert_equal(MisskeyService.create_tag('#宮本 佳那子 '), '#宮本_佳那子')
      end
    end
  end
end
