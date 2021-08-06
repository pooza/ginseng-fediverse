module Ginseng
  module Fediverse
    class Service
      include Package
      attr_reader :token, :http
      attr_accessor :mulukhiya_enable

      def initialize(uri = nil, token = nil)
        @config = config_class.instance
        @token = token || default_token
        @mulukhiya_enable = false
        @http = http_class.new
        @http.base_uri = Ginseng::URI.parse(uri) if uri
        @http.base_uri ||= default_uri
      end

      def uri
        return http.base_uri
      end

      def token=(token)
        @token = token
        @account = nil
      end

      def mulukhiya_enable?
        return @mulukhiya_enable || false
      end

      alias mulukhiya? mulukhiya_enable?

      def retry_limit
        return http.retry_limit
      end

      def retry_limit=(cnt)
        http.retry_limit = cnt
      end

      def nodeinfo
        return http.get('/nodeinfo/2.0').parsed_response
      end

      alias info nodeinfo

      def node_name
        return nodeinfo.dig('metadata', 'nodeName')
      end

      def maintainer_name
        return nodeinfo.dig('metadata', 'maintainer', 'name')
      end

      def maintainer_email
        return nodeinfo.dig('metadata', 'maintainer', 'email')
      end

      def upload(path, params = {})
        raise Ginseng::ImplementError, "'#{__method__}' not implemented"
      end

      def upload_remote_resource(uri, params = {})
        path = File.join(environment_class.dir, 'tmp/media', uri.to_s.adler32)
        File.write(path, http.get(uri))
        return upload(path, params)
      ensure
        File.unlink(path) if File.exist?(path)
      end

      def fetch_featured_tags(id, params = {})
        return nil
      end

      def filters(params = {})
        return nil
      end

      def announcements(params = {})
        return nil
      end

      def create_uri(href)
        return http.create_uri(href)
      end

      def create_streaming_uri(stream = 'user')
        raise Ginseng::ImplementError, "'#{__method__}' not implemented"
      end

      alias streaming_uri create_streaming_uri

      def self.create_tag(word)
        return "##{create_tag_base(word)}"
      end

      def self.create_tag_base(word)
        return word.strip.gsub(/[^[:alnum:]]+/, '_').gsub(/(^[_#]+|_$)/, '')
      end

      private

      def oauth_client_path
        return File.join(environment_class.dir, 'tmp/cache/oauth_cilent.json')
      end

      def clear_oauth_client
        File.unlink(oauth_client_path) if File.exist?(oauth_client_path)
      end

      def create_headers(headers)
        headers ||= {}
        headers['X-Mulukhiya'] = package_class.full_name unless mulukhiya_enable?
        return headers
      end

      def default_token
        raise Ginseng::ImplementError, "'#{__method__}' not implemented"
      end

      def default_uri
        raise Ginseng::ImplementError, "'#{__method__}' not implemented"
      end
    end
  end
end
