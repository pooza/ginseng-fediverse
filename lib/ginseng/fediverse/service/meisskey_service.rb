module Ginseng
  module Fediverse
    class MeisskeyService < MisskeyService
      include Package

      def announcements(params = {})
        response = http.get('/api/meta')
        return response['announcements'].map do |entry|
          entry.deep_symbolize_keys.merge(
            id: entry.to_json.adler32,
            content: entry['text'],
          )
        end
      end

      def max_post_text_length
        length = info.dig('metadata', 'maxNoteTextLength')
        length ||= config['/meisskey/status/default_max_length']
        return length
      end

      def max_media_attachments
        return @config['/meisskey/attachment/limit']
      end

      def default_token
        return @config['/meisskey/token']
      end

      def default_uri
        return URI.parse(@config['/meisskey/url'])
      end
    end
  end
end
