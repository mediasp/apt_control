module AptControl
  class PackageStates
    include Enumerable

    def initialize(options)
      @apt_site      = options.fetch(:apt_site)
      @build_archive = options.fetch(:build_archive)
      @control_file  = options.fetch(:control_file)
    end

    # yield a package state for each entry in the control file
    def each(&block)
      @control_file.distributions.each do |dist|
        dist.package_rules.each do |rule|
          yield PackageState.new(dist: dist, rule: rule, apt_site: @apt_site,
            build_archive: @build_archive)
        end
      end
    end

    def find_state(dist_name, package_name)
      find do |state|
        state.dist.name == dist_name && state.package_name == package_name
      end
    end
  end

  # Brings together the state of a particular package in a particular
  # distribution
  class PackageState

    attr_reader :dist, :rule

    def initialize(options)
      @dist          = options.fetch(:dist)
      @rule          = options.fetch(:rule)
      @apt_site      = options.fetch(:apt_site)
      @build_archive = options.fetch(:build_archive)
    end

    def included
      @included ||= @apt_site.included_version(dist.name, rule.package_name)
    end

    def available
      @available ||= (@build_archive[rule.package_name] || [])
    end

    def package_name ; rule.package_name ; end
    def included? ;    !! included       ; end
    def available? ;   available.any?    ; end

    def satisfied?
      included? && rule.satisfied_by?(included)
    end

    def includeable?
      available? && rule.includeable?(included, available)
    end

    def includeable_to
      rule.includeable_to(available)
    end

    def status_line
      [
        dist.name,
        package_name,
        "(#{rule.restriction} #{rule.version})",
        "#{includeable? ? 'I' : '.'}#{satisfied? ? 'S' : '.'}",
        "included=#{included || '<none>'}",
        "available=#{available? ? available.join(', ') : '<none>'} "
      ].join(' ')
    end

  end
end
