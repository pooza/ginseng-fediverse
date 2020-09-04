module Ginseng
  module Fediverse
    class CITestCaseFilter < Ginseng::TestCaseFilter
      include Package

      def active?
        pp 222
        return environment_class.ci?
      end
    end
  end
end
