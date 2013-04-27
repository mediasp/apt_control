require 'climate'
require 'yaml'

module AptControl

  module ConfigDSL

    def config(key, description, options={})
      options = {:required => true}.merge(options)
      configs << [key, description, options]
    end

    def configs
      @configs ||= []
    end
  end

  class CLI

    def self.main
      Climate.with_standard_exception_handling do
        Root.run(ARGV)
      end
    end

    module Common
      def apt_site ; ancestor(Root).apt_site ; end
      def control_file ; ancestor(Root).control_file ; end
      def build_archive ; ancestor(Root).build_archive ; end
      def notifier ; ancestor(Root).notify ; end
      def notify(msg) ; ancestor(Root).notify(msg) ; end
      def validate_config! ; ancestor(Root).validate_config! ; end

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

      opt :config_file, "Location of a config file where all options can be set",
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

        hash = if file
          YAML.load_file(file).each do |key, value|
            stderr.puts("Warn: Unknown key in config file: #{key}") unless self.class.cli_options.
              find {|opt| opt.name.to_s == key.to_s }
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
        @logger ||= Logger.new(config[:log_file] || STDOUT)
      end

      def apt_site
        @apt_site ||= AptSite.new(config[:apt_site_dir], logger)
      end

      def control_file
        @control_file ||= ControlFile.new(config[:control_file])
      end

      def build_archive
        @build_archive ||= BuildArchive.new(config[:build_archive_dir], logger)
      end

      def notifier
        @notify ||= Notify::Jabber.new(:jid => config[:jabber_id],
          :password => config[:jabber_password], :room_jid => config[:jabber_chatroom_id])
      end

      def notify(message)
        return unless config[:jabber_enabled]
        notifier.message(message)
      end

    end

    class Watch < Climate::Command('watch')
      include Common
      subcommand_of Root
      description """Watch the build archive for new files to include"""

      opt :noop, "Only pretend to do stuff to the apt archive"

      def run
        validate_config!

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

    class Status < Climate::Command('status')
      include Common
      subcommand_of Root
      description "Dump current state of apt site and build archive"

      opt :machine_readable, "If true, output in a unix-friendly format", :default => false

      def run
        validate_config!

        control_file.distributions.each do |dist|
          puts dist.name unless options[:machine_readable]
          dist.package_rules.each do |rule|
            included = apt_site.included_version(dist.name, rule.package_name)
            available = build_archive[rule.package_name]

            satisfied = included && rule.satisfied_by?(included)
            upgradeable = available && rule.upgradeable?(included, available)

            if options[:machine_readable]
              fields = [
                dist.name,
                rule.package_name,
                "(#{rule.restriction} #{rule.version})",
                "#{upgradeable ? 'U' : '.'}#{satisfied ? 'S' : '.'}",
                "included=#{included || '<none>'}",
                "available=#{available && available.join(', ') || '<none>'} "
              ]
              puts fields.join(' ')
            else
              puts "  #{rule.package_name}"
              puts "    rule       - #{rule.restriction} #{rule.version}"
              puts "    included   - #{included}"
              puts "    available  - #{available && available.join(', ')}"
              puts "    satisfied  - #{satisfied}"
              puts "    upgradeable - #{upgreadable}"
            end
          end
        end
      end
    end

  end
end
