module Ginseng
  module Fediverse
    class NoteURI < Ginseng::URI
      include Package

      def initialize(options = {})
        super
        @config = Config.instance
        @logger = logger_class.new
      end

      def note_id
        @config['/parser/note/url/patterns'].each do |pattern|
          next unless matches = path.match(pattern)
          return matches[1]
        end
        return nil
      end

      alias id note_id

      def valid?
        return absolute? && id.present?
      end

      def publicize!
        self.path = "/notes/#{id}" if id
        return self
      end

      def publicize
        return clone.publicize!
      end

      def visibility
        return note['visibility']
      end

      # 連合なし（`localOnly`）か。⚠ チャンネルのノートもここに入る。
      def local_only?
        return note['localOnly'] ? true : false
      end

      # 外へ出してよい公開範囲か。
      #
      # 🔴🔴 **`visibility` だけで決めない (#302)。** Misskey の連合なしのノートは
      # `visibility` が `public` のままで、`localOnly` が別に立つ。⚠⚠ 利用側は
      # この判定で**本文を外部へ転載するか**を決めている（`ginseng-piefed` の
      # `clip`、`mulukhiya-toot-proxy` のクリップ）ので、`visibility` だけを見ると
      # **作者が連合させないと決めた本文が外へ出る**。
      def public?
        return visibility == 'public' && !local_only?
      end

      def parser
        unless @parser
          @parser = NoteParser.new(note['text'])
          @parser.service = service
        end
        return @parser
      end

      def subject
        unless @subject
          @subject = note['cw'] if note['cw'].present?
          @subject ||= note['text']
          @subject.sanitize!
          URI.scan(@subject.dup) {|uri| @subject.gsub!(uri.to_s, '')}
          @subject.gsub!(/[\s[:blank:]]+/, ' ')
        end
        return @subject
      end

      def service
        unless @service
          uri = clone
          uri.path = '/'
          uri.query = nil
          uri.fragment = nil
          @service = MisskeyService.new(uri)
          @service.token = nil
        end
        return @service
      end

      def note
        unless @note
          @note = service.fetch_status(id)
          raise NotFoundError, "Note '#{self}' not found" unless @note
          if error = note['error']
            raise GatewayError, "Note '#{self}' is invalid (#{error['message']})"
          end
        end
        return @note
      end

      alias status note
    end
  end
end
