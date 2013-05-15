require 'stringio'
require 'xmpp4r/jid'
require 'xmpp4r/client'
require 'xmpp4r/muc'
require 'xmpp4r/muc/helper/simplemucclient'

module AptControl::Notify

  class Jabber
    include ::Jabber

    attr_reader :muc

    def initialize(options={})
      @jid      = options[:jid]
      @password = options[:password]
      @room_jid = options[:room_jid]
      @logger   = options[:logger]

      connect!
    end

    def connect!
      # ::Jabber::debug = true
      @logger.info("Jabber connecting with jid #{@jid}")
      @client = Client.new(JID.new(@jid))
      @client.connect
      @client.auth(@password)

      @muc = Jabber::MUC::SimpleMUCClient.new(@client)
      @muc.join(JID.new(@room_jid))
      @logger.info("joined room #{@room_jid}")
    end

    def message(msg)
      @muc.send(Message.new(nil, msg))
    end
  end
end
