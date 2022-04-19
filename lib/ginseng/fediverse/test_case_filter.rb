module Ginseng
  module Fediverse
    class TestCaseFilter < Ginseng::TestCaseFilter
      include Package

      def self.create(name)
        return all.find {|v| v.name == name}
      end

      def self.all
        return enum_for(__method__) unless block_given?
        Config.instance.raw.dig('test', 'filters').each do |entry|
          yield "Ginseng::Fediverse::#{entry['name'].camelize}TestCaseFilter".constantize.new(entry)
        end
      end
    end
  end
end
