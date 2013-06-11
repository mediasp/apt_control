require 'xmpp4r/jid'
require 'xmpp4r/client'
require 'xmpp4r/muc'
require 'xmpp4r/muc/helper/simplemucclient'

module AptControl
  class Jabber
    include ::Jabber

    def initialize(options)
      @jid      = options[:jid]
      @password = options[:password]
      @room_jid = options[:room_jid]
      @logger   = options[:logger]

      @room_nick = @room_jid && @room_jid.split('/').last
      @room_listeners = []

      swallow_errors { connect! } unless options[:defer_connect]
    end

    def room_nick
      @room_nick
    end

    def send_message(msg)
      if not_connected?
        connect!
      end

      begin
        attempt_reconnect do
          @logger.info("sending message to chat room: #{msg}")
          @muc.send(Message.new(nil, msg))
        end
      rescue JabberError => e
        raise SendError.new("failed to send message to chat room", e)
      end
    end

    # execute the block, swallow any Jabber::Error errors it raises, reporting
    # them to the logger
    def swallow_errors(jabber_errors_too=false, &block)
      begin
        yield(self)
      rescue Error => e
        @logger.error("swallowed error: #{e}")
        @logger.error(e)
      rescue JabberError => e
        raise unless jabber_errors_too
        @logger.error("swallowed error: #{e}")
        @logger.error(e)
      end
    end

    def connected?
      @client && @client.is_connected? && @muc && @muc.active?
    end

    def not_connected? ; ! connected? ; end

    def add_room_listener(listener)
      @room_listeners << listener
    end

    private

    def attempt_reconnect(&block)
      begin
        yield
      rescue JabberError => e
        @logger.error("swallowing jabber error: #{e}")
        @logger.error(e)
        @logger.error("attempting message send again...")
        connect!
        yield
      end
    end

    def connect!
      # ::Jabber::debug = true
      begin
        swallow_errors { @client.disconnect if @client && @client.is_connected? }

        @logger.info("Jabber connecting with jid #{@jid}")
        @client = Client.new(JID.new(@jid))
        @client.connect
        @client.auth(@password)
      rescue JabberError => e
        raise ConnectionError.new("error connecting to client", e)
      end

      begin
        swallow_errors { @muc.exit("reconnecting") if @muc && @muc.active? }

        @muc = Jabber::MUC::SimpleMUCClient.new(@client)
        @muc.join(JID.new(@room_jid))
        @logger.info("joined room #{@room_jid}")
        setup_muc_callbacks
      rescue JabberError => e
        raise ConnectionError.new("error joining room", e)
      end
    end

    def setup_muc_callbacks
      @muc.on_message do |time, nick, text|
        next if time # skip history
        next if @room_nick == nick
        notify_room_listeners(text)
      end
    end

    def notify_room_listeners(text)
      @room_listeners.each do |l|
        begin
          l.on_message(text)
        rescue => e
          @logger.error("listener #{l} raised error: #{e}")
          @logger.error(e)
        end
      end
    end

    # Thank you to http://rubyforge.org/projects/nestegg for the pattern
    class Error < StandardError

      attr_reader :cause
      alias :wrapped_error :cause

      def initialize(msg, cause=nil)
        @cause = cause
        super(msg)
      end

      def set_backtrace(bt)
        if cause
          bt << "cause: #{cause.class.name}: #{cause}"
          bt.concat cause.backtrace
        end
        super(bt)
      end

    end

    class ConnectionError < Error ; end
    class SendError < Error ; end
  end
end
