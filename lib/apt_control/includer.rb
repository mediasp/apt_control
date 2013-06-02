module AptControl

  # Wraps the common functionality involved in including the latest upgradeable
  # package in an apt site
  class Includer
    def initialize(apt_site, build_archive)
      @apt_site = apt_site
      @build_archive = build_archive
    end

    def perform_for(state, version, noop=false)
      changes_fname = @build_archive.changes_fname(state.package_name, version)
      @apt_site.include!(state.dist.name, changes_fname) unless noop
    end
  end
end
