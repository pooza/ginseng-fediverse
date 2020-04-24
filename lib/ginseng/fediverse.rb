require 'ginseng'
require 'active_support/dependencies/autoload'

module Ginseng
  module Fediverse
    extend ActiveSupport::Autoload

    autoload :Config
    autoload :Environment
    autoload :Logger
    autoload :Package
    autoload :Service
    autoload :TagContainer

    autoload_under 'service' do
      autoload :DolphinService
      autoload :MastodonService
      autoload :MisskeyService
    end
  end
end
