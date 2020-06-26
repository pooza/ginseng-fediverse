require 'digest/sha1'

module Ginseng
  module Fediverse
    class Service
      include Package
      attr_accessor :token
      attr_accessor :mulukhiya_enable

      def initialize(uri = nil, token = nil)
        @config = config_class.instance
        @token = token
        @mulukhiya_enable = false
        @http = http_class.new
      end

      def uri
        return @http.base_uri
      end

      def mulukhiya_enable?
        return @mulukhiya_enable || false
      end

      alias mulukhiya? mulukhiya_enable?

      def upload(path, params = {})
        raise Ginseng::ImplementError, "'#{__method__}' not implemented"
      end

      def upload_remote_resource(uri)
        path = File.join(
          environment_class.dir,
          'tmp/media',
          Digest::SHA1.hexdigest(uri),
        )
        File.write(path, @http.get(uri))
        return upload(path)
      ensure
        File.unlink(path) if File.exist?(path)
      end

      def self.create_tag(word)
        return '#' + word.strip.gsub(/[^[:alnum:]]+/, '_').gsub(/(^[_#]+|_$)/, '')
      end

      private

      def oauth_client_path
        return File.join(environment_class.dir, 'tmp/cache/oauth_cilent.json')
      end

      def clear_oauth_client
        File.unlink(oauth_client_path) if File.exist?(oauth_client_path)
      end
    end
  end
end
