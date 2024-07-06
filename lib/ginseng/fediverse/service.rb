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
        @http.base_uri = uri ? URI.parse(uri) : default_uri
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
        headers = {'X-Mulukhiya' => Package.full_name}
        r = http.get('/.well-known/nodeinfo', {headers:}).parsed_response
        return http.get(r['links'].first['href'], {headers:}).parsed_response
      rescue
        return {}
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

      def max_post_text_length
        return nil
      end

      def max_media_attachments
        return nil
      end

      def characters_reserved_per_url
        return nil
      end

      def upload(path, params = {})
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def upload_remote_resource(uri, params = {})
        path = File.join(environment_class.dir, 'tmp/media', uri.to_s.sha256)
        File.write(path, http.get(uri))
        return upload(path, params)
      ensure
        FileUtils.rm_f(path)
      end

      def fetch_featured_tags(id, params = {})
        return nil
      end

      def fetch_followed_tags(params = {})
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
        raise ImplementError, "'#{__method__}' not implemented"
      end

      alias streaming_uri create_streaming_uri

      def create_headers(headers = {})
        headers ||= {}
        headers['X-Mulukhiya'] ||= package_class.full_name unless mulukhiya_enable?
        return headers
      end

      def default_token
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def default_uri
        raise ImplementError, "'#{__method__}' not implemented"
      end

      def self.sanitize_status(text)
        text = text.dup
        text.delete!("\n") if text.match?(/<br.*?>/)
        text.gsub!(/[[:blank:]]*<br.*?>/, "\n")
        text.gsub!(%r{[[:blank:]]*</p.*?>}, "\n\n")
        text.gsub!(/<p.*?>/, '')
        text.sanitize!
        text.gsub!(/[@#]/, '\\0 ')
        return text.strip
      end

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
        FileUtils.rm_f(oauth_client_path)
      end
    end
  end
end
