require 'ginseng'
require 'active_support/dependencies/autoload'
require 'ginseng/fediverse/refines'

module Ginseng
  module Fediverse
    extend ActiveSupport::Autoload
    using Refines

    autoload :Acct
    autoload :Config
    autoload :Environment
    autoload :Logger
    autoload :Package
    autoload :Parser
    autoload :Service
    autoload :TagContainer
    autoload :TestCase
    autoload :TestCaseFilter

    autoload_under 'parser' do
      autoload :NoteParser
      autoload :TootParser
    end

    autoload_under 'service' do
      autoload :DolphinService
      autoload :MastodonService
      autoload :MeisskeyService
      autoload :MisskeyService
      autoload :PleromaService
    end

    autoload_under 'test_case_filter' do
      autoload :CITestCaseFilter
    end
  end
end
