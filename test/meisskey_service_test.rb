module Ginseng
  module Fediverse
    class MeisskeyServiceTest < Test::Unit::TestCase
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

      def test_mulukhiya?
        assert_false(@meisskey.mulukhiya?)
        assert_false(@meisskey.mulukhiya_enable?)
        @meisskey.mulukhiya_enable = true
        assert(@meisskey.mulukhiya?)
        assert(@meisskey.mulukhiya_enable?)
        @meisskey.mulukhiya_enable = false
      end

      def test_note
        return if Environment.ci?
        r = @meisskey.note('文字列からノート')
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['createdNote']['text'], '文字列からノート')
      end

      def test_announcements
        return if Environment.ci?
        assert_kind_of(Array, @meisskey.announcements)
      end

      def test_statuses
        return if Environment.ci?
        assert_kind_of(Array, @meisskey.statuses(account_id: @config['/meisskey/account/id']))
      end

      def test_upload
        return if Environment.ci?
        assert(@meisskey.upload(File.join(Environment.dir, 'images/pooza.jpg')).present?)
      end

      def test_upload_remote_resource
        return if Environment.ci?
        assert(@meisskey.upload_remote_resource('https://www.b-shock.co.jp/images/ota-m.gif').present?)
      end

      def test_create_tag
        assert_equal(MeisskeyService.create_tag('宮本佳那子'), '#宮本佳那子')
        assert_equal(MeisskeyService.create_tag('宮本 佳那子'), '#宮本_佳那子')
        assert_equal(MeisskeyService.create_tag('宮本 佳那子 '), '#宮本_佳那子')
        assert_equal(MeisskeyService.create_tag('#宮本 佳那子 '), '#宮本_佳那子')
      end
    end
  end
end
