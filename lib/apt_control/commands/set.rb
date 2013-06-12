module AptControl
  class Commands::Set

    def initialize(dependencies)
      @control_file = dependencies.fetch(:control_file)
    end

    def run(distribution_name, package_name, constraint)
      distribution = @control_file[distribution_name] or
        raise ArgumentError, "no such distribution: #{distribution_name}"

      package_rule = distribution[package_name] or
        raise ArgumentError, "no such package: #{package_name}"

      begin
        package_rule.constraint = constraint
      rescue => e
        raise ArgumentError, "could not set constraint: #{e}"
      end

      @control_file.write
    end
  end
end
