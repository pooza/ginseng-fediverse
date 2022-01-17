module Ginseng
  module Fediverse
    class TootURI < Ginseng::URI
      include Package

      def initialize(options = {})
        super
        @config = Config.instance
        @logger = logger_class.new
      end

      def toot_id
        @config['/parser/toot/url/patterns'].each do |pattern|
          next unless matches = path.match(pattern)
          id = matches[1]
          return id.to_i if id.match?(/^[[:digit:]]+$/)
          return id
        end
        return nil
      end

      alias id toot_id

      def account_id
        return nil unless matches = %r{^/users/([[:word:]]+)/statuses/[[:digit:]]+}i.match(path)
        return matches[1]
      end

      def valid?
        return absolute? && id.present?
      end

      def publicize!
        self.path = "/@#{account_id}/#{toot_id}" if account_id && toot_id
        return self
      end

      def publicize
        return clone.publicize!
      end

      def visibility
        return toot['visibility']
      end

      def public?
        return visibility == 'public'
      end

      def subject
        unless @subject
          @subject = toot['spoiler_text'] if toot['spoiler_text'].present?
          @subject ||= toot['content']
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
          @service = MastodonService.new(uri)
          @service.token = nil
        end
        return @service
      end

      def toot
        unless @toot
          @toot = service.fetch_status(id)
          raise NotFoundError, "Toot '#{self}' not found" unless @toot
          raise GatewayError, "Toot '#{self}' is invalid (#{toot['error']})" if @toot['error']
        end
        return @toot
      end

      alias status toot
    end
  end
end
