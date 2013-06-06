module AptControl::CLI
  class Include < Climate::Command('include')
    include Common
    subcommand_of Root
    description """Include in the apt site all packages from the build-archive
that the control file will allow"""

    opt :noop, "Do a dry run, printing what you would do out to stdout", :default => false

    def run
      validate_config!

      includer.perform_for_all(package_states) do |state, version|
        if options[:noop]
          puts "#{state.dist.name} #{state.package_name} #{state.included} => #{version}"
          false
        else
          true
        end
      end
    end
  end
end

