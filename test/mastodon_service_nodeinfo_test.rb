module Ginseng
  module Fediverse
    # nodeinfo の metadata 組み立て。連絡先アカウント未設定のインスタンスで
    # NoMethodError にならないこと (#238)。
    class MastodonServiceNodeinfoTest < TestCase
      def create_service(nodeinfo)
        service = MastodonService.new(Ginseng::URI.parse('https://mstdn.example.com/'))
        service.instance_variable_set(:@nodeinfo, nodeinfo)
        return service
      end

      def test_maintainer_with_contact_account
        service = create_service(
          'email' => 'admin@example.com',
          'contact_account' => {'display_name' => 'ぷぅざ', 'username' => 'pooza'},
        )

        assert_equal('ぷぅざ', service.maintainer['name'])
        assert_equal('admin@example.com', service.maintainer['email'])
      end

      def test_maintainer_falls_back_to_username
        service = create_service(
          'email' => 'admin@example.com',
          'contact_account' => {'display_name' => '', 'username' => 'pooza'},
        )

        assert_equal('pooza', service.maintainer['name'])
      end

      # 管理画面で連絡先アカウントが未設定なら contact_account が nil になる。
      # 以前はここで NoMethodError になり nodeinfo 全体が取れなかった。
      def test_maintainer_without_contact_account
        service = create_service('email' => 'admin@example.com')

        assert_nil(service.maintainer['name'])
        assert_equal('admin@example.com', service.maintainer['email'])
      end
    end
  end
end
