module AptControl::CLI
  class Watch < Climate::Command('watch')
    include Common
    subcommand_of Root
    description """Watch the build archive for new files to include

DAEMON

The watch command can run as a daemon, backgrounding itself after start up and
has the usual set of options for running as an init.d style daemon.
"""

    opt :noop, "Only pretend to do stuff to the apt archive"
    opt :daemonize, "Run watcher in the background", :default => false
    opt :pidfile, "Pidfile when daemonized", :type => :string
    opt :setuid, "Once daemonized, call setuid with this user id to drop privileges", :type => :integer

    def run
      validate_config!

      # hit these before we daemonize so we don't just background and die
      apt_site
      control_file
      build_archive

      daemonize! if options[:daemonize]

      start_watching
    end


    def daemonize!
      pidfile = options[:pidfile]

      if pidfile && File.exists?(pidfile)
        $stderr.puts("pidfile exists, not starting")
        exit 1
      end

      if uid = options[:setuid]
        logger.info("setting uid to #{uid}")
        begin
          Process::Sys.setuid(uid)
        rescue Errno::EPERM => e
          raise Climate::ExitException, "Could not setuid with #{uid}"
        end
      end

      pid = fork
      exit 0 unless pid.nil?

      File.open(pidfile, 'w') {|f| f.write(Process.pid) } if pidfile

      at_exit { File.delete(pidfile) if File.exists?(pidfile) } if pidfile
    end

    def start_watching
      # update the all the rules if the control file changes
      Thread.new { control_file.watch { notify "Control file reloaded" } }

      notify("Watching for new packages in #{build_archive.dir}")

      build_archive.watch do |package, new_version|
        notify("new package: #{package.name} at #{new_version}")

        matched_states = package_states.select {|s| s.package_name == package.name }

        updated = matched_states.map do |state|
          if state.upgradeable_to.max == new_version
            begin
              includer.perform_for(state, new_version, options[:noop])
              notify("included package #{package.name}-#{new_version} in #{state.dist.name}")
              state.dist.name
            rescue => e
              notify("Failed to include package #{package.name}-#{new_version}, check log for more details")
              logger.error("failed to include package #{package.name}")
              logger.error(e)
            end
          end
        end.compact

        if updated.size == 0
          notify("package #{package.name} could not be updated on any distributions")
        end
      end
    end
  end
end
