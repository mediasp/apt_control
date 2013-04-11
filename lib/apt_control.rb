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

    class Package
      def versions ; end
      def changes_fname(version) ; end

      def packages ; end
    end
  end

  class ControlFile

    def initialize(path)
      @inifile = IniFile.load(path)
      parse!
    end

    def dump
      @distributions.each do |d|
        puts "#{d}"
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

    def distributions ; end
  end

  class AptSite
    include Exec::Helpers

    def initialize(apt_site_dir)
      @apt_site_dir = apt_site_dir
    end

    def included_version(distribution_name, package_name)
      `reprepro -b #{apt_site_dir}`
    end
    def include!(distribution_name, changes_fname) ; end
  end
end
