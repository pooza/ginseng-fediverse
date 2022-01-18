module Ginseng
  module Fediverse
    class MeisskeyService < MisskeyService
      include Package

      def announcements(params = {})
        return info.dig('metadata', 'announcements').map do |entry|
          {
            id: entry.to_json.adler32,
            title: entry['title'],
            text: entry['text'],
            content: entry['text'],
          }
        end
      end

      def max_post_text_length
        return info.dig('metadata',
                        'maxNoteTextLength') || config['/meisskey/note/default_max_length']
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
