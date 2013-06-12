module AptControl::CLI
  class Set < Climate::Command('set')
    include Common
    subcommand_of Root
    description "Set a version restriction for a package and distribution"

    arg :distribution, "Name of distribution"
    arg :package, "Name of package"
    arg :constraint, "Version constraint, i.e. '>= 1.5'"

    def run
      validate_config!

      begin
        AptControl::Commands::Set.new(control_file: control_file).
          run(arguments[:distribution], arguments[:package], arguments[:constraint])
      rescue ArgumentError => e
        raise Climate::ExitException, e.message
      end
    end
  end
end
