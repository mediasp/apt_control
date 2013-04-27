module AptControl::CLI
  class Watch < Climate::Command('watch')
    include Common
    subcommand_of Root
    description """Watch the build archive for new files to include"""

    opt :noop, "Only pretend to do stuff to the apt archive"

    def run
      validate_config!

      Thread.new { control_file.watch }

      notify("Watching for new packages in #{build_archive.dir}")
      build_archive.watch do |package, new_version|
        notify("new package: #{package.name} at #{new_version}")

        updated = control_file.distributions.map do |dist|
          rule = dist[package.name] or next
          included = apt_site.included_version(dist.name, package.name)

          if rule.upgradeable?(included, [new_version])
            if options[:noop]
              notify("package #{package.name} can be upgraded to #{new_version} on #{dist.name} (noop)")
            else
              # FIXME error handling here, please
              apt_site.include!(dist.name, build_archive.changes_fname(rule.package_name, new_version))
              notify("package #{package.name} upgraded to #{new_version} on #{dist.name}")
            end
            dist.name
          else
            nil
          end
        end.compact

        if updated.size == 0
          notify("package #{package.name} could not be updated on any distributions")
        end
      end
    end
  end
end
