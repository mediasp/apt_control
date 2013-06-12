module AptControl::CLI
  class Promote < Climate::Command('promote')
    include Common
    subcommand_of Root
    description "Promote a currently included package from one distribution to another"

    arg :src_distribution,  "Name of distribution to find currently included package version"
    arg :dest_distribution, "Name of distribution to update"
    arg :package,           "Name of package to promote"

    def run
      validate_config!

      begin
        promote_cmd = AptControl::Commands::Promote.new(
          control_file: control_file,
          package_states: package_states)

        begin
          promote_cmd.run(arguments[:src_distribution],
            arguments[:dest_distribution],
            arguments[:package])
        rescue ArgumentError => e
          raise Climate::ExitException, e.message
        end
      end
    end
  end
end
