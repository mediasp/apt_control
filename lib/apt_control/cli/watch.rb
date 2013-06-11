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

    # for the watch command, we use the actor version of the apt_site so that
    # reprepro operations are sequential
    def new_includer
      super(apt_site: apt_site.actor)
    end

    def start_watching
      threads = [
        watch_control_in_new_thread,
        watch_build_archive_in_new_thread,
        jabber_enabled? && start_aptbot_in_new_thread
      ].compact

      notify("apt_control watcher is up, waiting for changes to control file and new packages...")

      # these should never exit, so stop main thread exiting by joining to them
      threads.each(&:join)
    end

    def start_aptbot_in_new_thread
      Thread.new do
        begin
          bot = AptControl::Bot.new(
            jabber:         jabber.actor,
            command_start:  jabber.room_nick,
            package_states: package_states,
            logger:         logger)

          jabber.add_room_listener(bot.actor)
        rescue => e
          puts "got an error #{e}"
          puts e.backtrace
        end
      end
    end

    def watch_control_in_new_thread
      # update the all the rules if the control file changes
      Thread.new do
        begin
          control_file.watch(fs_listener_factory) do
            notify "Control file reloaded"
            # FIXME need to do some kind of locking or actor style dev for this
            # as it looks like there could be some concurrency bugs lurking
            new_includer.perform_for_all(package_states) do |package_state, new_version|
              notify("included package #{package_state.package_name}-#{new_version} in #{package_state.dist.name}")
              true
            end
          end
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
        if state.includeable_to.max == new_version
          begin
            new_includer.perform_for(state, new_version, options[:noop])
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
