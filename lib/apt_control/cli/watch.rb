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
      threads = [
        watch_control_in_new_thread,
        watch_build_archive_in_new_thread
      ]

      # these should never exit, so stop main thread exiting by joining to them
      threads.each(&:join)
    end

    def watch_control_in_new_thread
      # update the all the rules if the control file changes
      Thread.new do
        begin
          control_file.watch(fs_listener_factory) { notify "Control file reloaded" }
        ensure
          logger.warn("control file watch loop exited")
        end
      end
    end

    def watch_build_archive_in_new_thread
      Thread.new do
        begin
          build_archive.watch(fs_listener_factory) do |package, new_version|
            handle_new_package(package, new_version)
          end
        ensure
          logger.warn("build archive watch loop exited")
        end
      end
    end

    def handle_new_package(package, new_version)
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
