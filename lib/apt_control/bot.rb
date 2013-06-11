module AptControl
  class Bot

    module ClassMethods
      def method_added(meth)
        super
        if match = /^handle_(.+)$/.match(meth.to_s)
          handlers << match[1]
        end
      end

      def handlers
        @handlers ||= []
      end
    end

    self.extend(ClassMethods)

    include Actors::Proxied
    proxy :on_message

    def initialize(dependencies)
      @jabber         = dependencies.fetch(:jabber)
      @package_states = dependencies.fetch(:package_states)
      @logger         = dependencies.fetch(:logger)
      @command_start  = dependencies.fetch(:command_start)

      @bot_pattern = /#{Regexp.escape(@command_start)}\: ([^ ]+)(?: (.+))?/
      @logger.info("looking for messages starting with #{@command_start}")
      @logger.debug("  match pattern: #{@bot_pattern}")
    end

    def on_message(text)
      return unless match = @bot_pattern.match(text)

      command, args = [match[1], match[2]]

      handler = self.class.handlers.include?(command) or
        return print_help("unknown command '#{command}'")

      args = args.nil? ? [] : args.split(' ')
      begin
        self.send("handle_#{command}", args)
      rescue => e
        @logger.error("error handling #{command}")
        @logger.error(e)
      end
    end

    def send_message(msg)
      @jabber.async.send_message(msg)
    end

    def print_help(message)
      send_message(message)
      send_message("Send commands with '#{@jabber.room_nick}: COMMAND [ARGS...]'")
      send_message("Available commands: #{self.class.handlers.join(' ')}")
    end

    def handle_status(args)
      dist = args[0]
      package_name = args[1]

      found = @package_states.map do |package_state|
        next if dist && dist != package_state.dist.name
        next if package_name && package_name != package_state.package_name

        send_message(package_state.status_line)
        true
      end.compact

      send_message("no packages found: distribution => #{dist.inspect}, package_name => #{package_name.inspect} ") if found.empty?
    end
  end
end
