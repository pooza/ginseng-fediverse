module Ginseng
  module Fediverse
    # サーバーから上限が取れないときは設定の既定値へ落ちる (#318)。
    # 以前は既定値を引く口が未定義の `config` を参照していて、NameError になっていた。
    class MaxPostTextLengthTest < TestCase
      SERVICES = {
        MastodonService => '/mastodon/status/default_max_length',
        MisskeyService => '/misskey/status/default_max_length',
        MeisskeyService => '/meisskey/status/default_max_length',
        PleromaService => '/pleroma/status/default_max_length',
      }.freeze

      def create_service(service_class, &)
        service = service_class.new(Ginseng::URI.parse('https://example.com/'))
        service.define_singleton_method(:info, &)
        return service
      end

      def test_without_length_in_info
        SERVICES.each do |service_class, key|
          service = create_service(service_class) {{}}

          assert_equal(Config.instance[key], service.max_post_text_length, service_class.name)
        end
      end

      def test_info_unavailable
        SERVICES.each do |service_class, key|
          service = create_service(service_class) {raise Ginseng::GatewayError, 'unavailable'}

          assert_equal(Config.instance[key], service.max_post_text_length, service_class.name)
        end
      end
    end
  end
end
