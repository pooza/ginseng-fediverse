module Ginseng
  module Fediverse
    class PleromaService < MastodonService
      include Package

      def say(body, params = {})
        params[:chat_id] ||= body[:chat_id]
        return http.post("/api/v1/pleroma/chats/#{params[:chat_id]}/messages", {
          body:,
          headers: create_headers(params[:headers]),
        })
      end

      def upload(path, params = {})
        params[:response] ||= :raw
        response = http.upload('/api/v1/media', path, {
          headers: create_headers(params[:headers]),
        })
        return response if params[:response] == :raw
        return JSON.parse(response.body)['id']
      end

      def reaction(id, emoji, params = {})
        return http.put("/api/v1/pleroma/statuses/#{id}/reactions/#{emoji}", {
          headers: create_headers(params[:headers]),
        })
      end

      def delete_reaction(id, emoji, params = {})
        return http.delete("/api/v1/pleroma/statuses/#{id}/reactions/#{emoji}", {
          headers: create_headers(params[:headers]),
        })
      end

      def announcements(params = {})
        return nil
      end

      def filters(params = {})
        return nil
      end

      def oauth_client(type = :default)
        unless File.exist?(oauth_client_path)
          response = http.post('/api/v1/apps', {
            body: {
              client_name: package_class.name,
              website: @config['/package/url'],
              redirect_uris: @config['/pleroma/oauth/redirect_uri'],
              scopes: @config['/pleroma/oauth/scopes'].join(' '),
            },
          })
          File.write(oauth_client_path, response.body)
        end
        return JSON.parse(File.read(oauth_client_path))
      end

      def create_tag_uri(tag)
        return create_uri("/tag/#{tag.to_hashtag_base}")
      end

      def oauth_uri(type = :default)
        return nil unless oauth_client(type)
        uri = create_uri('/oauth/authorize')
        uri.query_values = {
          client_id: oauth_client(type)['client_id'],
          response_type: 'code',
          redirect_uri: @config['/pleroma/oauth/redirect_uri'],
          scope: @config['/pleroma/oauth/scopes'].join(' '),
        }
        return uri
      end

      def auth(code, type = :default)
        return http.post('/oauth/token', {
          headers: {'Content-Type' => 'application/x-www-form-urlencoded'},
          body: {
            'grant_type' => 'authorization_code',
            'redirect_uri' => @config['/pleroma/oauth/redirect_uri'],
            'client_id' => oauth_client(type)['client_id'],
            'client_secret' => oauth_client(type)['client_secret'],
            'code' => code,
          },
        })
      end

      def nodeinfo
        unless @nodeinfo
          @nodeinfo = super
          @nodeinfo['metadata'] = {
            'nodeName' => @nodeinfo['title'],
            'maintainer' => {'name' => @nodeinfo['email'], 'email' => @nodeinfo['email']},
          }
        end
        return @nodeinfo
      end

      alias info nodeinfo

      def max_post_text_length
        return info['max_toot_chars'] || config['/pleroma/status/default_max_length']
      rescue
        return config['/pleroma/status/default_max_length']
      end

      def max_media_attachments
        return @config['/pleroma/attachment/limit']
      end

      def characters_reserved_per_url
        return 23
      end

      def default_token
        return @config['/pleroma/token']
      end

      def default_uri
        return URI.parse(@config['/pleroma/url'])
      end
    end
  end
end
