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

      opt :apt_site_dir, "Directory containing apt files"
      opt :control_file, "Path to control file containing inclusion rules", :type => :string

      def run
        puts "I am running"

        control_file = ControlFile.new(options[:control_file])
        control_file.dump
#        apt_site = AptSite.new(options[:apt_site_dir])
#        apt_site.included_version
      end
    end

  end
end
