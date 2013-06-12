module AptControl
  class Commands::Promote

    def initialize(dependencies)
      @control_file   = dependencies.fetch(:control_file)
      @package_states = dependencies.fetch(:package_states)
    end

    def run(src_name, dest_name, pkg_name)
      source_dist = @control_file[src_name] or
        raise ArgumentError, "source distribution '#{src_name}' does not exist"

      dest_dist = @control_file[dest_name] or
        raise ArgumentError, "destination distribution '#{dest_name}' does not exist"

      src_state = @package_states.find_state(src_name, pkg_name) or
        raise ArgumentError, "package '#{pkg_name}' does not exist in distribution '#{src_name}'"

      if not src_state.included?
        raise ArgumentError, "no '#{pkg_name}' package included in '#{src_name}' to promote"
      end
      new_constraint = "= #{src_state.included.to_s}"
      dest_dist[pkg_name] = new_constraint

      @control_file.write
    end
  end
end
