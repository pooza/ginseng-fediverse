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

      ACCOUNT_ID_PATTERNS = [
        %r{^/users/([[:word:]]+)/statuses/[[:digit:]]+}i,
        %r{^/ap/users/([[:digit:]]+)/statuses/[[:digit:]]+}i,
      ].freeze

      # path に現れるアカウント識別子。`/users/<username>/` では username を、
      # numeric_ap_id 形式 `/ap/users/<id>/` では数値 ID を返す (#243)。
      def account_id
        ACCOUNT_ID_PATTERNS.each do |pattern|
          next unless matches = pattern.match(path)
          return matches[1]
        end
        return nil
      end

      # 公開 URL `/@<username>/<id>` を組み立てられる場合の username。
      # numeric_ap_id 形式では数値 ID しか分からず、`/@` は username を前提と
      # するため nil を返す。
      def account_username
        id = account_id
        return nil if id.nil? || id.match?(/^[[:digit:]]+$/)
        return id
      end

      def valid?
        return absolute? && id.present?
      end

      # 公開 Web URL 形式へ書き換える。
      #
      # ⚠ numeric_ap_id 形式 `/ap/users/<id>/statuses/<id>` は no-op。数値 ID から
      # username を解くには API 往復が要り、publicize はフィード生成の per-link
      # 経路から呼ばれるためここではネットワークを踏まない。誤った `/@<数値 ID>/`
      # を作るくらいなら AP 形式のまま返す (#243)。
      def publicize!
        self.path = "/@#{account_username}/#{toot_id}" if account_username && toot_id
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
