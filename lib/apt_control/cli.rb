require 'climate'

module AptControl
  class CLI

    def self.init_commands
#      re
    end

    def self.main
      init_commands

      Climate.with_standard_exception_handling do
        Root.run(ARGV)
      end
    end

    class Root < Climate::Command('apt_control')
      description """
Move packages from an archive in to your reprepro style apt repository
"""

      opt :apt_site_dir, "Directory containing apt files", :type => :string
      opt :control_file, "Path to control file containing inclusion rules", :type => :string
      opt :build_archive_dir, "Directory containing debian build files", :type => :string

      def run
        control_file = ControlFile.new(options[:control_file])
        apt_site = AptSite.new(options[:apt_site_dir])
        build_archive = BuildArchive.new(options[:build_archive_dir])

        control_file.distributions.each do |dist|
          puts dist.name
          dist.package_rules.each do |rule|
            included = apt_site.included_version(dist.name, rule.package_name)
            available = build_archive[rule.package_name]

            puts "  #{rule.package_name}"
            puts "    rule       - #{rule.restriction} #{rule.version}"
            puts "    included   - #{included}"
            puts "    available  - #{available && available.versions.join(', ')}"

          end
        end
      end
    end

  end
end
