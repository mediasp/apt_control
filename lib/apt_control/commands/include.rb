module AptControl
  class Commands::Include

    def initialize(dependencies)
      @apt_site      = dependencies.fetch(:apt_site)
      @build_archive = dependencies.fetch(:build_archive)
    end

    def run(package_states, &visitor)
      package_states.map do |state|
        next unless state.includeable?

        version = state.includeable_to.max
        perform = (block_given? && yield(state, version)) || true

        perform_for(state, version) && [state, version] if perform
      end.compact
    end

    def perform_for(state, version, noop=false)
      changes_fname = @build_archive.changes_fname(state.package_name, version)
      @apt_site.include!(state.dist.name, changes_fname) unless noop
    end
  end
end
