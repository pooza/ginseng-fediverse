module Ginseng
  module Fediverse
    class CITestCaseFilter < TestCaseFilter
      include Package

      def active?
        return environment_class.ci?
      end
    end
  end
end
