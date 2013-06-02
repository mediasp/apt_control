module AptControl::CLI
  class Include < Climate::Command('include')
    include Common
    subcommand_of Root
    description """Include in the apt site all packages from the build-archive
that the control file will allow"""

    opt :noop, "Do a dry run, printing what you would do out to stdout", :default => false

    def run
      validate_config!

      package_states.each do |state|
        next unless state.upgradeable?

        version = state.upgradeable_to.max
        if options[:noop]
          puts "#{state.dist.name} #{state.package_name} #{state.included} => #{version}"
        else
          includer.perform_for(state, version)
        end
      end
    end
  end
end

