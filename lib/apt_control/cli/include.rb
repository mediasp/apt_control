module AptControl::CLI
  class Include < Climate::Command('include')
    include Common
    subcommand_of Root
    description """Include in the apt site all packages from the build-archive
that the control file will allow"""

    opt :noop, "Do a dry run, printing what you would do out to stdout", :default => false

    def run
      validate_config!

      control_file.distributions.each do |dist|
        dist.package_rules.each do |rule|
          included = apt_site.included_version(dist.name, rule.package_name)
          available = build_archive[rule.package_name]

          next unless available

          if rule.upgradeable?(included, available)
            version = rule.upgradeable_to(available).max
            if options[:noop]
              puts "I want to upgrade from #{included} to version #{version} of #{rule.package_name}"
            else
              apt_site.include!(dist.name, build_archive.changes_fname(rule.package_name, version))
            end
          end
        end
      end
    end
  end
end

