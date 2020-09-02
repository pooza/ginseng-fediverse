require 'digest/sha1'

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

      def nodeinfo
        r = http.get('/nodeinfo/2.0')
        raise Ginseng::GatewayError, "Bad response #{r.code}" unless r.code == 200
        return r.parsed_response
      end

      alias info nodeinfo

      def upload(path, params = {})
        raise Ginseng::ImplementError, "'#{__method__}' not implemented"
      end

      def upload_remote_resource(uri, params = {})
        path = File.join(
          environment_class.dir,
          'tmp/media',
          Digest::SHA1.hexdigest(uri),
        )
        File.write(path, http.get(uri))
        return upload(path, params)
      ensure
        File.unlink(path) if File.exist?(path)
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

      def self.create_tag(word)
        return "##{create_tag_base(word)}"
      end

      def self.create_tag_base(word)
        return word.strip.gsub(/[^[:alnum:]]+/, '_').gsub(/(^[_#]+|_$)/, '').to_s
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
        return Ginseng::URI.parse(@config['/dolphin/url'])
      end
    end
  end
end
