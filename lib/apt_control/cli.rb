require 'climate'
require 'yaml'

module AptControl

  # Some class methods for defining config keys
  module ConfigDSL

    def config(key, description, options={})
      options = {:required => true}.merge(options)
      configs << [key, description, options]
    end

    def configs
      @configs ||= []
    end
  end

  module CLI

    def self.main
      init_commands

      Climate.with_standard_exception_handling do
        begin
          Root.run(ARGV)
        rescue Exec::UnexpectedExitStatus => e
          $stderr.puts("Error executing: #{e.command}")
          $stderr.puts(e.stderr)
          exit 1
        end
      end
    end

    def self.init_commands
      require 'apt_control/cli/status'
      require 'apt_control/cli/watch'
      require 'apt_control/cli/include'
    end

    module Common
      # FIXME tidy up with some meta magic
      def package_states ; ancestor(Root).package_states ; end
      def new_includer(options={}) ; ancestor(Root).new_includer(options) ; end
      def apt_site ; ancestor(Root).apt_site ; end
      def control_file ; ancestor(Root).control_file ; end
      def build_archive ; ancestor(Root).build_archive ; end
      def jabber ; ancestor(Root).jabber ; end
      def jabber_enabled? ; ancestor(Root).jabber_enabled? ; end
      def notify(msg) ; ancestor(Root).notify(msg) ; end
      def validate_config! ; ancestor(Root).validate_config! ; end
      def logger ; ancestor(Root).logger ; end
      def fs_listener_factory ; ancestor(Root).fs_listener_factory ; end

      def each_package_state(&block)
        control_file.distributions.each do |dist|
          dist.package_rules.each do |rule|
            included = apt_site.included_version(dist.name, rule.package_name)
            available = build_archive[rule.package_name]

            yield(dist, rule, included, available)
          end
        end
      end
    end

    class Root < Climate::Command('apt_control')

      class << self
        include ConfigDSL
      end

      DEFAULT_CONFIG_FILE_LOCATION = '/etc/apt_control/config.yaml'

      config :log_file, "File to send log output to, defaults to /dev/null", :required => false
      config :apt_site_dir, "Directory containing apt files"
      config :control_file, "Path to control file containing inclusion rules"
      config :build_archive_dir, "Directory containing debian build files"
      config :jabber_enabled, "Enable jabber integration", :required => false
      config :jabber_id, "Jabber ID for notifications", :required => false
      config :jabber_password, "Password for connecting to jabber server", :required => false
      config :jabber_chatroom_id, "Jabber ID for chatroom to send notifications to", :required => false
      config :disable_inotify, "Set to true to disable use of inotify", :required => false

      description """
Move packages from an archive in to your reprepro style apt repository.

CONFIG

All configuration can be set by passing an option on the command line, but you can
avoid having to pass these each time by using a config file.  By default,
apt_control looks for #{DEFAULT_CONFIG_FILE_LOCATION}, which is expected to be a
YAML file containing a single hash of key value/pairs for each option.

#{configs.map {|k, d| "#{k}: #{d}" }.join("\n\n") }
"""

      opt :config_file, "Alternative location for config file",
        :type => :string, :short => 'f'

      opt :config_option, "Supply a config option on the command line", :multi => true,
        :type => :string, :short => 'o'

      def config
        @config ||= build_config
      end

      #
      # Read yaml file if one exists, then apply overrides from the command line
      #
      def build_config
        file = [options[:config_file], DEFAULT_CONFIG_FILE_LOCATION].
          compact.find {|f| File.exists?(f) }

        hash =
          if file
            YAML.load_file(file).each do |key, value|
            stderr.puts("Warn: Unknown key in config file: #{key}") unless
              self.class.configs.find {|opt| opt.first.to_s == key.to_s }
          end
          else
            {}
          end

        options[:config_option].map {|str| str.split('=') }.
          inject(hash) {|m, (k,v)| m.merge(k.to_sym => v) }
      end

      def validate_config!
        self.class.configs.each do |key, desc, options|
          if options[:required]
            config[key] or raise Climate::ExitException, "Error: No config supplied for #{key}"
          end
        end

        if config[:jabber_enabled]
          self.class.configs.each do |key, desc, options|
            next unless key.to_s['jabber_']
            config[key] or raise Climate::ExitException, "Error: you must supply all jabber options if jabber is enabled"
          end
        end

        Celluloid.logger = logger
      end

      def logger
        log_file = config[:log_file] || '/dev/null'
        @logger ||= Logger.new(log_file == 'STDOUT' ? STDOUT : log_file).tap do |logger|
          logger.level = Logger::DEBUG
        end
      end

      def package_states
        @package_states ||= PackageStates.new(apt_site: apt_site,
          build_archive: build_archive,
          control_file: control_file)
      end

      def apt_site
        @apt_site ||= AptSite.new(config[:apt_site_dir], logger)
      end

      def control_file
        @control_file ||= ControlFile.new(config[:control_file], logger)
      end

      def build_archive
        @build_archive ||= BuildArchive.new(config[:build_archive_dir], logger)
      end

      def jabber
        @jabber ||= Jabber.new(:jid => config[:jabber_id], :logger => logger,
          :password => config[:jabber_password], :room_jid => config[:jabber_chatroom_id],
          :enabled => jabber_enabled?)
      end

      def jabber_enabled?
        config[:jabber_enabled].to_s == 'true'
      end

      def new_includer(options={})
        defaults = {apt_site: apt_site, build_archive: build_archive}
        options = options.merge(defaults)

        Includer.new(options[:apt_site], options[:build_archive])
      end

      class FSListenerFactory

        attr_reader :disable_inotify

        def initialize(options={})
          @disable_inotify = options[:disable_inotify]
        end

        def new(dir, pattern, &on_change)
          Listen.to(dir).filter(pattern).tap do |listener|
            if disable_inotify
              listener.force_polling(true)
              listener.polling_fallback_message(false)
            else
              listener.force_adapter(Listen::Adapters::Linux)
            end

            listener.change(&on_change)
          end
        end
      end

      def fs_listener_factory
        @fs_listener_factory ||= FSListenerFactory.new(
          disable_inotify: config[:disable_inotify].to_s == 'true')
      end

      def notify(message)
        logger.info("notify: #{message}")
        begin
          jabber.actor.async.send_message(message)
        rescue => e
          logger.error("Unable to send notification to jabber: #{e}")
          logger.error(e)
        end
      end
    end
  end
end

