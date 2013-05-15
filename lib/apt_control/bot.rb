module AptControl
  class Bot
    include ::Jabber

    COMMAND_REGEX = /apt_bot( [^ ]+)?( .+)?/

    def initialize(dependencies)
      @muc_client = dependencies.fetch(:muc_client)
      @control_file = dependencies.fetch(:control_file)
      @apt_site = dependencies.fetch(:apt_site)
      @build_archive = dependencies.fetch(:build_archive)
    end

    def start
      setup_hooks!
      report_initial_state!
    end

    def report_initial_state!
    end

    def message(msg)
      @muc_client.send(Message.new(nil, msg))
    end

    def handle_help(args)
      message("Commands: help, status")
    end

    def handle_status(args)

      dist_names = @control_file.distributions.map(&:name)

      puts "args.inspect: #{args.inspect}"

      if args.nil? || args.empty?
        message("Please supply a distribution. (#{dist_names.join(', ')})")
        return
      end

      dist = @control_file.distributions.find {|d| d.name == args.first }

      if dist.nil?
        message("'#{args.first}' Not found, pick one of: (#{dist_names.join(', ')})")
        return
      end

      dist.package_rules.each do |rule|
        send_status_message(dist, rule)
      end
    end

    def send_status_message(dist, rule)
      included = @apt_site.included_version(dist.name, rule.package_name)
      available = @build_archive[rule.package_name]

      satisfied = included && rule.satisfied_by?(included)
      upgradeable = available && rule.upgradeable?(included, available)

      message "rule: #{rule.restriction} #{rule.version}"
      message "included: #{included}"
      message "available: #{available && available.join(', ')}"
      message "satisfied: #{satisfied}"
      message "upgradeable: #{upgradeable}"
    end




    def setup_hooks!
      @muc_client.on_message do |time, nick, text|
        # don't respond to room history
        next if time
        begin
          puts "Got message from #{nick}: #{text}"

          matched = COMMAND_REGEX.match(text)
          next unless matched

          command = matched[1] && matched[1].strip
          args = matched[2] && matched[2].strip.split(/ +/)

          puts "parsed as:"
          puts "  command: #{command.inspect}"
          puts "     args: #{args.inspect}"

          if command.nil?
            handle_help([])
          elsif methods.include?(method_name = "handle_#{command}")
            self.send(method_name, args)
          else
            message("Don't know how to respond to: #{command}")
            handle_help([])
          end
        rescue => e
          $stderr.puts(e)
        end
      end
    end

  end
end
