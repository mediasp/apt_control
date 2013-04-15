# -*- coding: utf-8 -*-
require 'inifile'
require 'listen'

module AptControl
  # - scan the contents of the build-archive
  # - scan the control file
  # - query the state of the apt-site
  #   - current version

  require 'apt_control/exec'
  require 'apt_control/notify'

  class Version
    include Comparable

    attr_reader :major, :minor, :bugfix, :debian

    def self.parse(string)
      match = /([0-9]+)(?:\.([0-9]+))?(?:\.([0-9]+))?(?:-(.+))?/.match(string)
      match && new(*(1..4).map { |i| match[i] }) or raise "could not parse #{string}"
    end

    def initialize(major, minor, bugfix, debian)
      @major = major && major.to_i
      @minor = minor && minor.to_i
      @bugfix = bugfix && bugfix.to_i
      @debian = debian
    end

    def to_a
      [@major, @minor, @bugfix, @debian]
    end

    def <=>(rhs)
      self.to_a.compact <=> rhs.to_a.compact
    end

    def ==(rhs)
      self.to_a == rhs.to_a
    end

    def =~(rhs)
      self.to_a[0...3] == rhs.to_a[0...3]
    end

    # = operator
    # returns true if this version satisfies the given rule and version spec,
    # where all parts of the version given match our parts.  Not commutative,
    # as  1.3.1.4 satisfies 1.3, but 1.3 does not satisfy 1.3.1.4
    def satisfies_exactly(rhs)
      rhs.to_a.compact.zip(self.to_a).each do |rhs_part, lhs_part|
        return false unless rhs_part == lhs_part
      end
      return true
    end

    # >= operator
    # returns true if this version is greater than or equal to the given version
    def satisfies_loosely(rhs)
      return true if satisfies_exactly(rhs)
      return true if (self.to_a.compact <=> rhs.to_a.compact) >= 0
      return false
    end

    # ~> operator
    def satisfies_pessimisticly(rhs)

      return false unless self.to_a[0...2] == rhs.to_a[0...2]

      lhs_half = self.to_a[2..-1]
      rhs_half = rhs.to_a[2..-1]

      (lhs_half.compact <=> rhs_half.compact) >= 0
    end

    def to_s
      [
        "#{major}.#{minor}",
        bugfix && ".#{bugfix}",
        debian && "-#{debian}"
      ].compact.join
    end
  end

  class VersionDeclaration
  end

  class BuildArchive

    attr_reader :packages
    attr_reader :dir

    def initialize(dir)
      @dir = File.expand_path(dir)
      parse!
    end

    def [](name)
      package = packages.find {|p| p.name == name }
      package && package.versions
    end

    def changes_fname(package_name, version)
      fname = Dir.chdir(@dir) do
        parsed_changes = Dir["#{package_name}_#{version}_*.changes"].find { |fname|
          parse_changes_fname(fname)
        }
      end

      fname && File.expand_path(File.join(@dir, fname))
    end

    def parse!
      Dir.chdir(@dir) do
        parsed_changes = Dir['*.changes'].map { |fname|
          begin ; parse_changes_fname(fname) ; rescue => e; $stderr.puts(e) ; end
        }.compact

        package_names = parsed_changes.map(&:first).sort.uniq
        @packages = package_names.map do |name|
          versions = parsed_changes.select {|n, v | name == n }.
            map(&:last).
            map {|s| begin ; Version.parse(s) ; rescue => e ; $stderr.puts(e) ; end }.
            compact
          Package.new(name, versions)
        end
      end
    end

    def parse_changes_fname(fname)
      name, version = fname.split('_')[0...2]
      raise "bad changes filename #{fname}" unless name and version
      [name, version]
    end

    def watch(&block)
      Listen.to(@dir, :filter => /\.changes$/) do |modified, added, removed|
        added.each do |fname|
          begin
            fname = File.basename(fname)
            name, version_string = parse_changes_fname(fname)
            version = Version.parse(version_string)

            package = @packages.find {|p| p.name == name }
            if package.nil?
              @packages << package = Package.new(name, [version])
            else
              package.add_version(version)
            end

            yield(package, version)
          rescue => e
            $stderr.puts("Could not parse changes filename #{fname}: #{e}")
            $stderr.puts(e.backtrace)
            next
          end
        end
      end
    end

    class Package

      attr_reader :name

      def initialize(name, versions)
        @name = name
        @versions = versions
      end

      def add_version(version)
        @versions << version
      end

      def versions
        @versions.sort
      end

      def changes_fname(version) ; end

    end
  end

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
      attr_reader :package_name
      attr_reader :version
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

      def higher_available?(included, available)
        available.find {|a| a > included }
      end

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

      def upgradeable?(included, available)
        return false unless higher_available?(included, available)
        return true if available.any? {|a| satisfied_by?(a) }
      end

      def upgradeable_to(available)
        available.select {|a| satisfied_by?(a) }
      end
    end

    class Distribution
      def initialize(name, rules)
        @name = name
        @package_rules = rules
      end
      attr_reader :name
      attr_reader :package_rules

      def [](package_name)
        package_rules.find {|rule| rule.package_name == package_name }
      end

    end

  end

  class AptSite
    include Exec::Helpers

    def initialize(apt_site_dir)
      @apt_site_dir = apt_site_dir
    end

    def reprepro_cmd
      "reprepro -b #{@apt_site_dir}"
    end

    def included_version(distribution_name, package_name)
      command = "#{reprepro_cmd} -Tdsc list #{distribution_name} #{package_name}"
      output = exec(command, :name => 'reprepro')
      version_string = output.split(' ').last
      version_string && Version.parse(version_string)
    end

    def include!(distribution_name, changes_fname)
      command = "#{reprepro_cmd} --ignore=wrongdistribution include #{distribution_name} #{changes_fname}"
      begin
        exec(command, :name => 'reprepro')
      rescue Exec::UnexpectedExitStatus => e
        $stderr.puts("Error executing: #{e.command}")
        $stderr.puts(e.stderr)
      end
    end
  end
end
