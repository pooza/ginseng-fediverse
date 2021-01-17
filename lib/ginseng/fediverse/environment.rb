module Ginseng
  module Fediverse
    class Environment < Ginseng::Environment
      def self.name
        return File.basename(dir)
      end

      def self.dir
        return Ginseng::Fediverse.dir
      end
    end
  end
end
