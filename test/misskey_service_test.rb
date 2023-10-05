module Ginseng
  module Fediverse
    class MisskeyServiceTest < TestCase
      def setup
        @config = Config.instance
        @service = MisskeyService.new(@config['/misskey/url'], @config['/misskey/token'])
      end

      def test_new
        assert_kind_of(MisskeyService, @service)
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

      def test_note
        r = @service.note('文字列からノート')

        assert_kind_of(HTTParty::Response, r)
        assert_equal(200, r.code)
        assert_equal('文字列からノート', r['createdNote']['text'])

        body = {text: 'HashWithIndifferentAccessからノート'}.with_indifferent_access
        r = @service.note(body)

        assert_kind_of(HTTParty::Response, r)
        assert_equal(200, r.code)
        assert_equal('HashWithIndifferentAccessからノート', r['createdNote']['text'])
      end

      def test_delete_status
        id = @service.note('このあと削除するノート')['createdNote']['id']
        r = @service.delete_status(id)

        assert_equal(204, r.code)
      end

      def test_announcements
        assert_kind_of(Array, @service.announcements)
        @service.announcements.each do |entry|
          assert_kind_of(Hash, entry)
          assert_predicate(entry[:id], :present?)
          assert_predicate(entry[:title], :present?)
          assert_predicate(entry[:text], :present?)
          assert_predicate(entry[:content], :present?)
        end
      end

      def test_antennas
        assert_kind_of(Array, @service.antennas)
        @service.antennas do |antenna|
          assert_kind_of(Hash, antenna)
          assert_predicate(antenna['id'], :present?)
          assert_predicate(antenna['title'], :present?)
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
        assert_kind_of(Array, @service.statuses(account_id: @config['/misskey/account/id']))
      end

      def test_upload
        assert_kind_of(RestClient::Response, @service.upload(File.join(Environment.dir, 'images/pooza.jpg')))
      end

      def test_upload_remote_resource
        assert_kind_of(RestClient::Response, @service.upload_remote_resource('https://anime-precure.com/import/images/precure20th_logo.webp'))
      end

      def test_delete_attachment
        response = @service.upload(File.join(Environment.dir, 'images/pooza.jpg'))
        id = JSON.parse(response.body)['id']
        r = @service.delete_attachment(id)

        assert_equal(204, r.code)
      end

      def test_create_parser
        assert_kind_of(NoteParser, @service.create_parser(''))
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
    end
  end
end
