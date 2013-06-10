require 'test/helpers'
require 'mocha/setup'
require 'stringio'

describe 'AptControl::Jabber' do

  JabberError = ::Jabber::JabberError

  def any_client_instance
    ::Jabber::Client.any_instance
  end

  def any_muc_instance
    ::Jabber::MUC::SimpleMUCClient.any_instance
  end

  before do
    # make these all no-ops until a test decides they should do something else
    any_client_instance.stubs(:connect)
    any_client_instance.stubs(:auth)
    any_muc_instance.stubs(:join)
  end

  let(:stringio) { StringIO.new }
  let(:jabber) { AptControl::Jabber.new(default_jabber_options)  }
  let(:cnx_state) { states('cnx') }
  let(:muc_state) {states('muc') }

  def muc_expects_message(message)
    any_muc_instance.expects(:send) do |_, msg|
      msg == message
    end
  end

  describe '#send_message' do
    describe 'when already connected' do
      it 'passes the message to the muc' do
        muc_expects_message(message)
        jabber.send_message('foo')
      end
    end

    def setup_client_and_muc_states(start_state='off')
      cnx_state.starts_as(start_state)
      muc_state.starts_as(start_state)

      any_client_instance.stubs(:is_connected?).returns(false).when(cnx_state.is('off'))
      any_client_instance.stubs(:is_connected?).returns(true).when(cnx_state.is('on'))

      any_muc_instance.stubs(:active?).returns(false).when(muc_state.is('off'))
      any_muc_instance.stubs(:active?).returns(true).when(muc_state.is('on'))
    end

    describe 'when the server has disconnected' do
      it 'attempts to connect, then sends the message' do

        setup_client_and_muc_states

        any_client_instance.expects(:connect).when(cnx_state.is('off')).then(cnx_state.is('connected'))
        any_client_instance.expects(:auth).when(cnx_state.is('connected')).then(cnx_state.is('on'))

        any_muc_instance.expects(:join).when(cnx_state.is('on')).when(muc_state.is('off')).then(muc_state.is('on'))


        muc_expects_message('foo').when(muc_state.is('on')).when(muc_state.is('on'))
        jabber.send_message('foo')
      end

      it 'attempts to connect, raises a ConnectionError when connect fails' do
        setup_client_and_muc_states

        any_client_instance.expects(:connect).
          raises(Jabber::JabberError.new('server gone away'))

        muc_expects_message('foo').never
        assert_raises AptControl::Jabber::ConnectionError do
          jabber.send_message('foo')
        end
      end

      it 'attempts to connect, raises a ConnectionError when auth fails' do
        setup_client_and_muc_states

        any_client_instance.expects(:connect).when(cnx_state.is('off')).then(cnx_state.is('connected'))
        any_client_instance.expects(:auth).when(cnx_state.is('connected')).
          raises(Jabber::JabberError.new("bad username password"))

        muc_expects_message('foo').never
        assert_raises AptControl::Jabber::ConnectionError do
          jabber.send_message('foo')
        end
      end
   end

    describe 'when the server disconnects half way through' do
      it 'sends the message, attempts to reconnect, then sends the message again' do
        setup_client_and_muc_states('on')
        attempts = sequence('attempts')

        # sends the message
        muc_expects_message('foo').raises(Jabber::JabberError.new('oh god'))\
          .when(muc_state.is('on')).when(cnx_state.is('on')).
          in_sequence(attempts)\
          .then(cnx_state.is('off')).then(muc_state.is('off'))

        # connection died, so reconnect
        any_client_instance.expects(:connect).when(cnx_state.is('off'))\
          .then(cnx_state.is('connected')).in_sequence(attempts)
        any_client_instance.expects(:auth).when(cnx_state.is('connected'))
          .then(cnx_state.is('on')).in_sequence(attempts)

        any_muc_instance.expects(:join).when(cnx_state.is('on'))\
          .when(muc_state.is('off')).then(muc_state.is('on')).
          in_sequence(attempts)

        # now send the message
        muc_expects_message('foo').when(muc_state.is('on'))\
          .when(cnx_state.is('on')).in_sequence(attempts)

        jabber.send_message('foo')
      end
    end

    describe 'when the server disconnects half way through, but keeps disconnecting every time the message tries to send' do
      it 'sends the message, attempts to reconnect, tries to send the message again, then raises an error' do
        setup_client_and_muc_states('on')

        # disconnect on send, should happen twice
        muc_expects_message('foo').raises(Jabber::JabberError.new('bad message'))\
          .when(muc_state.is('on')).when(cnx_state.is('on'))\
          .then(cnx_state.is('off')).then(muc_state.is('off'))
          .twice

        # we should see one connection attempt
        any_client_instance.expects(:connect).when(cnx_state.is('off'))\
          .then(cnx_state.is('connected'))
        any_client_instance.expects(:auth).when(cnx_state.is('connected'))
          .then(cnx_state.is('on'))

        any_muc_instance.expects(:join).when(cnx_state.is('on'))\
          .when(muc_state.is('off')).then(muc_state.is('on'))

        assert_raises AptControl::Jabber::SendError do
          jabber.send_message('foo')
        end
      end
    end

    describe 'when the server has gone away' do
      it 'attempts to connect, fails and raises an error' do
      end
    end
  end

  def pretend_client_disconnected
    any_client_instance.stubs(:is_connected?).returns(false)
    any_client_instance.stubs(:is_disconnected?).returns(true)
    any_muc_instance.stubs(:active?).returns(false)
  end

  def default_jabber_options
    {
      defer_connect: true,
      logger: Logger.new(stringio)
    }
  end

  describe '#connect!' do

    it 'wraps any JabberError from client.connect with ConnectionError' do

      any_client_instance.expects(:connect).raises(JabberError.new)

      assert_raises AptControl::Jabber::ConnectionError do
        jabber.send(:connect!)
      end

      any_client_instance.expects(:connect).raises(ArgumentError.new)

      assert_raises ArgumentError do
        jabber.send(:connect!)
      end
    end

    it 'wraps any JabberError from client.auth with ConnectionError' do
      any_client_instance.expects(:auth).raises(JabberError.new)

      assert_raises AptControl::Jabber::ConnectionError do
        jabber.send(:connect!)
      end

      any_client_instance.expects(:connect).raises(ArgumentError.new)

      assert_raises ArgumentError do
        jabber.send(:connect!)
      end
    end

    it 'wraps any JabberError from muc.join with ConnectionError' do
      any_muc_instance.expects(:join).raises(JabberError.new)

      assert_raises AptControl::Jabber::ConnectionError do
        jabber.send(:connect!)
      end

      any_muc_instance.expects(:join).raises(ArgumentError.new)

      assert_raises ArgumentError do
        jabber.send(:connect!)
      end
    end

  end

end
