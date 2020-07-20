module Ginseng
  module Fediverse
    class DolphinServiceTest < Test::Unit::TestCase
      def setup
        @config = Config.instance
        @dolphin = DolphinService.new(@config['/dolphin/url'], @config['/dolphin/token'])
      end

      def test_new
        assert_kind_of(DolphinService, @dolphin)
      end

      def test_uri
        assert_kind_of(URI, @dolphin.uri)
      end

      def test_mulukhiya?
        assert_false(@dolphin.mulukhiya?)
        assert_false(@dolphin.mulukhiya_enable?)
        @dolphin.mulukhiya_enable = true
        assert(@dolphin.mulukhiya?)
        assert(@dolphin.mulukhiya_enable?)
        @dolphin.mulukhiya_enable = false
      end

      def test_note
        return if Environment.ci?
        r = @dolphin.note('文字列からノート')
        assert_kind_of(HTTParty::Response, r)
        assert_equal(r.code, 200)
        assert_equal(r['createdNote']['text'], '文字列からノート')
      end

      def test_upload
        return if Environment.ci?
        assert(@dolphin.upload(File.join(Environment.dir, 'images/pooza.jpg')).present?)
      end

      def test_upload_remote_resource
        return if Environment.ci?
        assert(@dolphin.upload_remote_resource('https://www.b-shock.co.jp/images/ota-m.gif').present?)
      end

      def test_create_tag
        assert_equal(DolphinService.create_tag('宮本佳那子'), '#宮本佳那子')
        assert_equal(DolphinService.create_tag('宮本 佳那子'), '#宮本_佳那子')
        assert_equal(DolphinService.create_tag('宮本 佳那子 '), '#宮本_佳那子')
        assert_equal(DolphinService.create_tag('#宮本 佳那子 '), '#宮本_佳那子')
      end
    end
  end
end
