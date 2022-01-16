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

      def public?
        return visibility == 'public'
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
          @subject.gsub!(/\s+/, ' ')
          @subject.sanitize!
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
          raise Ginseng::NotFoundError, "Note '#{self}' not found" unless @note
          if note['error']
            raise Ginseng::GatewayError, "Note '#{self}' is invalid (#{note.dig('error', 'message')})"
          end
        end
        return @note
      end

      alias status note
    end
  end
end
