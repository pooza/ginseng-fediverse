require 'bundler/setup'
require 'ginseng/fediverse/refines'

module Ginseng
  module Fediverse
    using Refines

    def self.dir
      return File.expand_path('../..', __dir__)
    end

    def self.loader
      config = YAML.load_file(File.join(dir, 'config/autoload.yaml'))
      loader = Zeitwerk::Loader.new
      loader.inflector.inflect(config['inflections'])
      loader.push_dir(File.join(dir, 'lib/ginseng/fediverse'), namespace: Ginseng::Fediverse)
      return loader
    end
  end
end

Bundler.require
Ginseng::Fediverse.loader.setup
