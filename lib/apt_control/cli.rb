require 'climate'

module AptControl
  class CLI

    def self.main
      init_commands

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
      description """
Move packages from an archive in to your reprepro style apt repository
"""

      opt :log_file, "File to send log output to, defaults to stdout", :type => :string
      opt :apt_site_dir, "Directory containing apt files", :type => :string
      opt :control_file, "Path to control file containing inclusion rules", :type => :string
      opt :build_archive_dir, "Directory containing debian build files", :type => :string
      opt :jabber_id, "Jabber ID for notifications", :type => :string
      opt :jabber_password, "Password for connecting to jabber server", :type => :string
      opt :jabber_chatroom_id, "Jabber ID for chatroom to send notifications to", :type => :string

      def logger
        @logger ||= Logger.new(options[:log_file] || STDOUT)
      end

      def apt_site
        @apt_site ||= AptSite.new(options[:apt_site_dir], logger)
      end

      def control_file
        @control_file ||= ControlFile.new(options[:control_file])
      end

      def build_archive
        @build_archive ||= BuildArchive.new(options[:build_archive_dir], logger)
      end

      def notifier
        @notify ||= Notify::Jabber.new(:jid => options[:jabber_id],
          :password => options[:jabber_password], :room_jid => options[:jabber_chatroom_id])
      end

      def notify(message)
        notifier.message(message)
      end

    end

    class Watch < Climate::Command('watch')
      include Common
      subcommand_of Root
      description """Watch the build archive for new files to include"""

      opt :noop, "Only pretend to do stuff to the apt archive"

      def run
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

      def run
        control_file.distributions.each do |dist|
          puts dist.name
          dist.package_rules.each do |rule|
            included = apt_site.included_version(dist.name, rule.package_name)
            available = build_archive[rule.package_name]

            puts "  #{rule.package_name}"
            puts "    rule       - #{rule.restriction} #{rule.version}"
            puts "    included   - #{included}"
            puts "    available  - #{available && available.join(', ')}"
            puts "    satisfied  - #{included && rule.satisfied_by?(included)}"
            puts "    upgradable - #{available && rule.upgradeable?(included, available)}"
          end
        end
      end
    end

  end
end
