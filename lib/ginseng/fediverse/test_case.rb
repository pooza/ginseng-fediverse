module Ginseng
  module Fediverse
    class TestCase < Ginseng::TestCase
      include Package

      def self.load(cases = nil)
        ENV['TEST'] = Package.name
        names(cases).each do |name|
          puts "+ case: #{name}" if Environment.test?
          require File.join(dir, "#{name}.rb")
        rescue => e
          puts "- case: #{name} (#{e.message})" if Environment.test?
        end
      end

      def self.names(cases = nil)
        if cases
          names = cases.split(',')
            .map {|v| [v, "#{v}Test", v.underscore, "#{v.underscore}_test"]}.flatten
            .select {|v| File.exist?(File.join(dir, "#{v}.rb"))}.compact
        else
          names = Dir.glob(File.join(dir, '*.rb')).map {|v| File.basename(v, '.rb')}
        end
        TestCaseFilter.all.select(&:active?).each {|v| v.exec(names)}
        return names.sort.to_set
      end

      def self.dir
        return File.join(Environment.dir, 'test')
      end
    end
  end
end
