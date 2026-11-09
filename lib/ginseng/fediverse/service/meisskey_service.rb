module Ginseng
  module Fediverse
    class MeisskeyService < MisskeyService
      include Package

      # ⚠⚠ **Meisskey はトークンをクエリ（`i`）に残す（v8.0.0 のリリース前レビュー・オーナー判断）。**
      # ストリーミングは `i` しか読まない（mei23/misskey `mei-m544` の `src/server/api/streaming.ts`
      # の `auth()`）。🔴 ヘッダにすると**黙って匿名で接続される**。🔴 **トークンは逆プロキシのログに
      # 残る**（引き受けた限界）。
      def create_streaming_uri(stream = nil)
        uri = super
        uri.query_values = {'i' => token}
        return uri
      end

      alias streaming_uri create_streaming_uri

      def create_streaming_headers
        return {}
      end

      alias streaming_headers create_streaming_headers

      def announcements(params = {})
        response = http.get('/api/meta')
        return response['announcements'].map do |entry|
          entry.deep_symbolize_keys.merge(
            id: entry.to_json.sha256,
            content: entry['text'],
          )
        end
      end

      def max_post_text_length
        length = info.dig('metadata', 'maxNoteTextLength')
        length ||= @config['/meisskey/status/default_max_length']
        return length
      rescue
        return @config['/meisskey/status/default_max_length']
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
