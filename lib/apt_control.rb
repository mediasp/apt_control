# -*- coding: utf-8 -*-
require 'inifile'

module AptControl
  # - scan the contents of the build-archive
  # - scan the control file
  # - query the state of the apt-site
  #   - current version

  require 'apt_control/exec'

  class Version
    def <=>(rhs) ; end
  end

  class VersionDeclaration
  end

  class BuildArchive

    attr_reader :packages

    def initialize(dir)
      @dir = dir
      parse!
    end

    def [](name)
      packages.find {|p| p.name == name }
    end

    def parse!
      Dir.chdir(@dir) do
        parsed_changes = Dir['*.changes'].map { |fname|
          fname.split('_')[0...2]
        }

        package_names = parsed_changes.map(&:first).sort.uniq
        @packages = package_names.map do |name|
          versions = parsed_changes.select {|n, v | name == n }.map(&:last)
          Package.new(name, versions)
        end
      end
    end

    class Package

      attr_reader :name
      attr_reader :versions

      def initialize(name, versions)
        @name = name
        @versions = versions
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
        constraint.split(" ").tap do |split|
          @version, @restriction = if split.size == 1
                                     [split.first, '=']
                                   else
                                     split
                                   end
        end
      end
    end

    class Distribution
      def initialize(name, rules)
        @name = name
        @package_rules = rules
      end
      attr_reader :name
      attr_reader :package_rules
    end

  end

  class AptSite
    include Exec::Helpers

    def initialize(apt_site_dir)
      @apt_site_dir = apt_site_dir
    end

    def included_version(distribution_name, package_name)
      command = "reprepro -Tdsc -b #{@apt_site_dir} list #{distribution_name} #{package_name}"
      output = exec(command, :name => 'reprepro')
      output.split(' ').last
    end

    def include!(distribution_name, changes_fname) ; end
  end
end
