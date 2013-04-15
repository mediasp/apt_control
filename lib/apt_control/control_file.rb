module AptControl

  # Loads and models the contents of a control.ini file
  # see example-control.ini in root of project for an example
  class ControlFile

    attr_reader :distributions

    def initialize(path)
      @inifile = IniFile.load(path)
      parse!
    end

    def dump
      @distributions.each do |d|
        puts "#{d.name}"
        d.package_rules.each do |pr|
          puts "  #{pr.package_name} #{pr.restriction} #{pr.version}"
        end
      end
    end

    def parse!
      @distributions = @inifile.sections.map do |section|
        rules = @inifile[section].map do |key, value|
          PackageRule.new(key, value)
        end
        Distribution.new(section, rules)
      end
    end

    class PackageRule
      # name of package rule applies to
      attr_reader :package_name

      # version number for restriction comparison
      attr_reader :version

      # symbol for rule
      attr_reader :restriction

      def initialize(name, constraint)
        @package_name = name
        version = nil
        constraint.split(" ").tap do |split|
          @restriction, version = if split.size == 1
                                     ['=', split.first]
                                   else
                                     split
                                   end
        end

        ['=', '>=', '~>'].include?(@restriction) or
          raise "unrecognised restriction: '#{@restriction}'"

        @version = Version.parse(version)
      end

      # will return true if their is a version in available that is higher
      # than included
      def higher_available?(included, available)
        available.find {|a| a > included }
      end

      # will return true if included satisfies this rule
      def satisfied_by?(included)
        case @restriction
        when '='
          included.satisfies_exactly(version)
        when '>='
          included.satisfies_loosely(version)
        when '~>'
          included.satisfies_pessimisticly(version)
        else raise "this shouldn't have happened"
        end
      end

      # will return true if a) there is a higher version available than is
      # included b) any of the available packages satisfy this rule
      def upgradeable?(included, available)
        return false unless higher_available?(included, available)
        return true if available.any? {|a| satisfied_by?(a) }
      end

      # will return the subset of versions from available that satisfy this rule
      def upgradeable_to(available)
        available.select {|a| satisfied_by?(a) }
      end
    end

    # represents a set of rules mapped to a particular distribution, i.e.
    # squeeze is a distribution
    class Distribution
      def initialize(name, rules)
        @name = name
        @package_rules = rules
      end
      attr_reader :name
      attr_reader :package_rules

      # find a PackageRule by package name
      def [](package_name)
        package_rules.find {|rule| rule.package_name == package_name }
      end
    end
  end
end
