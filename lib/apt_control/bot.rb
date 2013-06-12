module AptControl
  class Bot

    # as a module for testing
    module ArgHelpers
      def split_args(args_string)
        # there is probably some code out there that can do this better, maybe
        # go out and find it if it proves troublsome :)
        args_string.scan(/[^ '"]+|'[^']+'|"[^"]+"/).map do |str|
          str.gsub(/'|"/, '')
        end
      end
    end

    include ArgHelpers

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
      @include_cmd    = dependencies.fetch(:include_cmd)
      @control_file   = dependencies.fetch(:control_file)

      @bot_pattern = /#{Regexp.escape(@command_start)}\: ([^ ]+)(?: (.+))?/
      @logger.info("looking for messages starting with #{@command_start}")
      @logger.debug("  match pattern: #{@bot_pattern}")
    end

    def on_message(text)
      return unless match = @bot_pattern.match(text)

      command, args = [match[1], match[2]]

      handler = self.class.handlers.include?(command) or
        return print_help("unknown command '#{command}'")

      args = split_args(args || '')
      begin
        self.send("handle_#{command}", args)
      rescue => e
        begin ; send_message("error: #{e}") ; rescue => e ; end
        @logger.error("error handling #{command}")
        @logger.error(e)
      end
    end

    def send_message(msg)
      @jabber.async.send_message(msg)
    end

    def print_help(message)
      send_message(message)
      send_message("Send commands with '#{@command_start} COMMAND [ARGS...]'")
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

    def handle_include(args)
      performed = @include_cmd.run(@package_states) do |state, version|
        send_message("#{state.dist.name} #{state.package_name} #{state.included} => #{version}")
        true
      end

      send_message("no packages were included") if performed.empty?
    end

    def handle_reload(args)
      @control_file.reload!
      send_message("control file reloaded")
    end

    def handle_set(args)
      set_command.run(*args)
    end

    def handle_promote(args)
      promote_command.run(*args)
    end

    def set_command
      AptControl::Commands::Set.new(control_file: @control_file)
    end

    def promote_command
      AptControl::Commands::Promote.new(control_file: @control_file,
        package_states: @package_states)
    end
  end
end
