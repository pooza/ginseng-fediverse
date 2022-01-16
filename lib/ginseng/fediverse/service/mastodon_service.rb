require 'rest-client'

module Ginseng
  module Fediverse
    class MastodonService < Service
      include Package

      def info
        unless @nodeinfo
          @nodeinfo = http.get('/api/v1/instance').parsed_response.merge(super)
          contact = @nodeinfo['contact_account']
          @nodeinfo['metadata'] = {
            'nodeName' => @nodeinfo['title'],
            'maintainer' => {
              'name' => contact['display_name'] || contact['username'],
              'email' => @nodeinfo['email'],
            },
          }
        end
        return @nodeinfo
      end

      alias nodeinfo info

      def search_status_id(status)
        if status.is_a?(URI) && (status.host == uri.host)
          uri = TootURI.parse(status)
          status = status.id if uri.valid?
        end
        return status
      end

      def search_attachment_id(attachment)
        return attachment
      end

      def fetch_status(id, params = {})
        response = http.get("/api/v1/statuses/#{search_status_id(id)}", {
          headers: create_headers(params[:headers]),
        })
        raise Ginseng::GatewayError, response['error'] if response['error']
        return response
      end

      alias fetch_toot fetch_status

      def post(body, params = {})
        body = {status: body.to_s} unless body.is_a?(Hash)
        return http.post('/api/v1/statuses', {
          body: body.compact,
          headers: create_headers(params[:headers]),
        })
      end

      alias toot post

      def delete_status(id, params = {})
        return http.delete("/api/v1/statuses/#{search_status_id(id)}", {
          headers: create_headers(params[:headers]),
        })
      end

      alias delete_toot delete_status

      def upload(path, params = {})
        params[:response] ||= :raw
        params[:version] ||= 1
        response = http.upload(
          "/api/v#{params[:version]}/media",
          path,
          create_headers(params[:headers]),
        )
        return response if params[:response] == :raw
        return JSON.parse(response.body)['id'].to_i
      end

      def update_media(id, payload, params = {})
        if [File, Tempfile].map {|c| payload.dig(:thumbnail, :tempfile).is_a?(c)}.any?
          path = payload.dig(:thumbnail, :tempfile).path
        end
        return http.put(
          "/api/v1/media/#{search_attachment_id(id)}",
          path,
          create_headers(params[:headers]),
          payload,
        )
      end

      alias update_attachment update_media

      def favourite(id, params = {})
        return http.post("/api/v1/statuses/#{search_status_id(id)}/favourite", {
          headers: create_headers(params[:headers]),
        })
      end

      alias fav favourite

      def reblog(id, params = {})
        return http.post("/api/v1/statuses/#{search_status_id(id)}/reblog", {
          headers: create_headers(params[:headers]),
        })
      end

      alias boost reblog

      def bookmark(id, params = {})
        return http.post("/api/v1/statuses/#{search_status_id(id)}/bookmark", {
          headers: create_headers(params[:headers]),
        })
      end

      def search(keyword, params = {})
        params[:version] ||= 2
        params[:q] = keyword
        uri = create_uri("/api/v#{params[:version]}/search")
        uri.query_values = params
        return http.get(uri, {headers: create_headers(params[:headers])})
      end

      def follow(id, params = {})
        return http.post("/api/v1/accounts/#{id}/follow", {
          headers: create_headers(params[:headers]),
        })
      end

      def unfollow(id, params = {})
        return http.post("/api/v1/accounts/#{id}/unfollow", {
          headers: create_headers(params[:headers]),
        })
      end

      def statuses(params = {})
        response = http.get('/api/v1/timelines/home', {headers: create_headers(params[:headers])})
        return response.parsed_response
      end

      alias toots statuses

      def announcements(params = {})
        response = http.get('/api/v1/announcements', {headers: create_headers(params[:headers])})
        return response.parsed_response.map do |announcement|
          entry = announcement.deep_symbolize_keys
          entry[:text] = entry[:content].sanitize.strip
          entry.delete(:read)
          entry
        end
      end

      def followers(params = {})
        id = params[:id] || @config['/mastodon/account/id']
        uri = create_uri("/api/v1/accounts/#{id}/followers")
        uri.query_values = {limit: @config['/mastodon/followers/limit']}
        return http.get(uri, {headers: create_headers(params[:headers])})
      end

      def followees(params = {})
        id = params[:id] || @config['/mastodon/account/id']
        uri = create_uri("/api/v1/accounts/#{id}/following")
        uri.query_values = {limit: @config['/mastodon/followees/limit']}
        return http.get(uri, {headers: create_headers(params[:headers])})
      end

      alias following followees

      def fetch_featured_tags(id, params = {})
        return http.get("/api/v1/accounts/#{id}/featured_tags", {
          headers: create_headers(params[:headers]),
        })
      end

      def filters(params = {})
        return http.get('/api/v1/filters', {headers: create_headers(params[:headers])})
      end

      def register_filter(params)
        return http.post('/api/v1/filters', {
          body: {
            phrase: params[:phrase],
            context: params[:context] || [:home, :public],
          },
          headers: create_headers(params[:headers]),
        })
      end

      def unregister_filter(id, params = {})
        return http.delete("/api/v1/filters/#{id}", {
          headers: create_headers(params[:headers]),
        })
      end

      def oauth_client(type = :default)
        unless File.exist?(oauth_client_path)
          response = http.post('/api/v1/apps', {
            body: {
              client_name: package_class.name,
              website: @config['/package/url'],
              redirect_uris: @config['/mastodon/oauth/redirect_uri'],
              scopes: @config['/mastodon/oauth/scopes'].join(' '),
            },
          })
          File.write(oauth_client_path, response.body)
        end
        return JSON.parse(File.read(oauth_client_path))
      end

      def oauth_uri(type = :default)
        return nil unless oauth_client(type)
        uri = create_uri('/oauth/authorize')
        uri.query_values = {
          client_id: oauth_client(type)['client_id'],
          response_type: 'code',
          redirect_uri: @config['/mastodon/oauth/redirect_uri'],
          scope: @config['/mastodon/oauth/scopes'].join(' '),
        }
        return uri
      end

      def auth(code, type = :default)
        return http.post('/oauth/token', {
          headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
          body: {
            'grant_type' => 'authorization_code',
            'redirect_uri' => @config['/mastodon/oauth/redirect_uri'],
            'client_id' => oauth_client(type)['client_id'],
            'client_secret' => oauth_client(type)['client_secret'],
            'code' => code,
          },
        })
      end

      def create_tag_uri(tag)
        return create_uri("/tags/#{tag.to_hashtag_base}")
      end

      alias tag_uri create_tag_uri

      def create_streaming_uri(stream = 'user')
        uri = Ginseng::URI.parse(info.dig('urls', 'streaming_api'))
        uri.path = '/api/v1/streaming'
        uri.query_values = {'access_token' => token, 'stream' => stream}
        return uri
      end

      alias streaming_uri create_streaming_uri

      def max_post_text_length
        return info.dig('configuration', 'statuses', 'max_characters')
      end

      def max_media_attachments
        return info.dig('configuration', 'statuses', 'max_media_attachments')
      end

      def default_token
        return @config['/mastodon/token']
      end

      private

      def create_headers(headers)
        headers ||= {}
        headers['Authorization'] ||= "Bearer #{token}"
        return super
      end

      def default_uri
        return Ginseng::URI.parse(@config['/mastodon/url'])
      end
    end
  end
end
