require 'thread'

module AptControl

  # Loads and models the contents of a control.ini file
  # see example-control.ini in root of project for an example
  class ControlFile

    def initialize(path, logger)
      @logger = logger
      @watch_mutex = Mutex.new
      @path = path
      @distributions =
        if File.exists?(@path)
          inifile = IniFile.load(@path)
          parse!(inifile)
        else
          []
        end
    end

    def distributions
      # not sure that this is strictly necessary - there is no true concurrency
      # in MRI/YARV, but that doesn't mean a thread couldn't be interrupted half
      # way through initialising a variable, does it?
      @watch_mutex.synchronize { @distributions }
    end

    def [](dist_name)
      distributions.find {|d| d.name == dist_name }
    end

    def dump
      @watch_mutex.synchronize do
        @distributions.each do |d|
          puts "#{d.name}"
          d.package_rules.each do |pr|
            puts "  #{pr.package_name} #{pr.restriction} #{pr.version}"
          end
        end
      end
    end

    def write
      IniFile.new.tap do |inifile|
        inifile.filename = @path
        distributions.each do |distribution|
          inifile[distribution.name] = distribution.inject({}) do |hash, rule|
            hash.tap do |h|
              # quote the restriction, as inifile doesn't do this for you
              # https://github.com/TwP/inifile/pull/16
              h[rule.package_name] = '"' + rule.restriction_string + '"'
            end
          end
        end
        inifile.write
      end
    end

    def parse!(inifile)
      inifile.sections.map do |section|
        rules = inifile[section].map do |key, value|
          PackageRule.new(key, value)
        end
        Distribution.new(section, rules)
      end
    end

    def reload!
      inifile = IniFile.load(@path)
      distributions = parse!(inifile)

      @watch_mutex.synchronize do
        @distributions = distributions
      end
    end

    # Watch the control file for changes, rebuilding
    # internal data structures when it does
    def watch(fs_listener_factory, &block)
      path = File.expand_path(@path)
      dir = File.dirname(path)
      fname = File.basename(path)
      @logger.info("Watching for changes to #{path}")
      fs_listener_factory.new(dir, /#{Regexp.quote(fname)}/) do |modified, added, removed|
        begin
          @logger.info("Change to control file detected...")
          reload!
          yield if block_given?
          @logger.info("...rebuilt")
        rescue => e
          @logger.error("Error reloading changes: #{e}")
          @logger.error(e)
        end
      end.start.join
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
      def includeable?(included, available)
        return false unless higher_available?(included, available)
        higher = available.select {|a| a > included }
        return true if higher.any? {|a| satisfied_by?(a) }
      end

      # will return the subset of versions from available that satisfy this rule
      def includeable_to(available)
        available.select {|a| satisfied_by?(a) }
      end

      def restriction_string
        "#{@restriction} #{@version}"
      end

      # FIXME to_s should include the package name
      alias :to_s :restriction_string
    end

    # represents a set of rules mapped to a particular distribution, i.e.
    # squeeze is a distribution
    class Distribution
      include Enumerable

      def initialize(name, rules)
        @name = name
        @package_rules = rules
      end
      attr_reader :name
      attr_reader :package_rules

      def each(&block)
        (@package_rules || []).each do |rule|
          yield(rule)
        end
      end

      # find a PackageRule by package name
      def [](package_name)
        package_rules.find {|rule| rule.package_name == package_name }
      end
    end
  end
end
