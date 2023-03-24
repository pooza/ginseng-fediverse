require 'securerandom'

module Ginseng
  module Fediverse
    class MastodonServiceTest < TestCase
      def setup
        @config = Config.instance
        @service = MastodonService.new(@config['/mastodon/url'], @config['/mastodon/token'])
        @toot_id = @config['/mastodon/test_toot']
        @filte_title = SecureRandom.hex
      end

      def test_new
        assert_kind_of(MastodonService, @service)
      end

      def test_uri
        assert_kind_of(URI, @service.uri)
      end

      def test_tag_uri
        assert_equal('/tags/日本語のタグ', @service.create_tag_uri('日本語のタグ').path)
      end

      def test_mulukhiya?
        assert_false(@service.mulukhiya?)
        assert_false(@service.mulukhiya_enable?)
        @service.mulukhiya_enable = true

        assert_predicate(@service, :mulukhiya?)
        assert_predicate(@service, :mulukhiya_enable?)
        @service.mulukhiya_enable = false
      end

      def test_toot
        r = @service.toot('文字列からトゥート')

        assert_kind_of(HTTParty::Response, r)
        assert_equal(200, r.code)
        assert_equal('<p>文字列からトゥート</p>', r['content'])

        r = @service.toot(status: 'ハッシュからプライベートなトゥート', visibility: 'private')

        assert_kind_of(HTTParty::Response, r)
        assert_equal(200, r.code)
        assert_equal('<p>ハッシュからプライベートなトゥート</p>', r['content'])
        assert_equal('private', r['visibility'])
      end

      def test_delete_status
        id = @service.toot('このあと削除するトゥート')['id']
        r = @service.delete_status(id)

        assert_equal(200, r.code)
        assert_equal('このあと削除するトゥート', r['text'])
      end

      def test_media
        id = @service.upload(File.join(Environment.dir, 'images/pooza.jpg'), {response: :id})

        assert_predicate(id, :positive?)

        r = @service.update_media(id, {description: 'hoge'})

        assert_equal(200, r.code)

        r = @service.update_media(id, {thumbnaiil: {
          tempfile: File.new(File.join(Environment.dir, 'images/pooza.jpg')),
        }})

        assert_equal(200, r.code)

        r = @service.update_media(id, {thumbnaiil: {
          tempfile: File.join(Environment.dir, 'images/pooza.jpg'),
        }})

        assert_equal(200, r.code)
      end

      def test_bookmark
        assert_equal(200, @service.bookmark(@toot_id).code)
      end

      def test_favourite
        assert_equal(200, @service.favourite(@toot_id).code)
      end

      def test_reblog
        assert_equal(200, @service.reblog(@toot_id).code)
      end

      def test_announcements
        assert_kind_of(Array, @service.announcements)
        @service.announcements.each do |entry|
          assert_kind_of(Hash, entry)
          assert_predicate(entry[:id], :present?)
          assert_predicate(entry[:text], :present?)
          assert_predicate(entry[:content], :present?)
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
        assert_kind_of(Array, @service.statuses)
      end

      def test_followers
        assert_equal(200, @service.followers.code)
      end

      def test_followees
        assert_equal(200, @service.followees.code)
      end

      def test_search
        assert_equal(200, @service.search('pooza').code)
        assert_equal(200, @service.search('pooza', {version: 2}).code)
      end

      def test_create_parser
        assert_kind_of(TootParser, @service.create_parser(''))
      end

      def test_upload_remote_resource
        assert_predicate(@service.upload_remote_resource('https://www.b-shock.co.jp/images/ota-m.gif', {response: :id}), :positive?)
      end

      def test_filters
        filters = @service.filters.parsed_response

        assert_kind_of(Array, filters)
        return unless filters.present?

        filters.first(5).each do |filter|
          assert_kind_of(String, filter['id'])
          assert_kind_of(Array, filter['keywords'])
        end

        filters.first['keywords'].each do |keyword|
          assert_kind_of(String, keyword['keyword'])
          assert_boolean(keyword['whole_word'])
        end
      end

      def test_register_filter
        filter = @service.register_filter(title: @filte_title, phrase: '実況')
        @service.unregister_filter(filter['id'])
      end

      def test_max_post_text_length
        assert_predicate(@service.max_post_text_length, :positive?)
      end

      def test_max_media_attachments
        assert_predicate(@service.max_media_attachments, :positive?)
      end

      def test_characters_reserved_per_url
        assert_predicate(@service.characters_reserved_per_url, :positive?)
      end

      def test_create_streaming_uri
        assert_kind_of(Ginseng::URI, @service.create_streaming_uri)
      end
    end
  end
end
