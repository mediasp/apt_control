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
        Root.run(ARGV)
      end
    end

    def self.init_commands
      require 'apt_control/cli/status'
      require 'apt_control/cli/watch'
      require 'apt_control/cli/include'
    end

    module Common
      def apt_site ; ancestor(Root).apt_site ; end
      def control_file ; ancestor(Root).control_file ; end
      def build_archive ; ancestor(Root).build_archive ; end
      def notifier ; ancestor(Root).notify ; end
      def notify(msg) ; ancestor(Root).notify(msg) ; end
      def validate_config! ; ancestor(Root).validate_config! ; end
      def logger ; ancestor(Root).logger ; end

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

      config :log_file, "File to send log output to, defaults to stdout", :required => false
      config :apt_site_dir, "Directory containing apt files"
      config :control_file, "Path to control file containing inclusion rules"
      config :build_archive_dir, "Directory containing debian build files"
      config :jabber_enabled, "Enable jabber integration", :required => false
      config :jabber_id, "Jabber ID for notifications", :required => false
      config :jabber_password, "Password for connecting to jabber server", :required => false
      config :jabber_chatroom_id, "Jabber ID for chatroom to send notifications to", :required => false

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
              self.class.cli_options.find {|opt| opt.name.to_s == key.to_s }
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
      end

      def logger
        @logger ||= Logger.new(config[:log_file] || STDOUT).tap do |logger|
          logger.level = Logger::DEBUG
        end
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

      def notifier
        @notify ||= Notify::Jabber.new(:jid => config[:jabber_id], :logger => logger,
          :password => config[:jabber_password], :room_jid => config[:jabber_chatroom_id])
      end

      def notify(message)
        logger.info("notify: #{message}")
        return unless config[:jabber_enabled]
        notifier.message(message)
      end
    end
  end
end

