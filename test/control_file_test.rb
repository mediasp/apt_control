require 'test/helpers'
require 'stringio'

describe 'AptControl::ControlFile' do
  include CLIHelper

  let(:stringio) { StringIO.new }
  let(:logger)   { Logger.new(stringio) }

  before do
    setup_dirs
  end

    it 'can read an inifile (smoke test)' do
      control :production => {
        'api'    => '1.3.4',
        'worker' => '1.5'
      }, :staging => {
        'dog'    => '= 1.2.3',
        'foo'    => '~> 0.1'
      }

      subject = AptControl::ControlFile.new(control_file, logger)
      assert subject.distributions.find {|d| d.name == 'production' }
      assert_equal '= 1.3.4', subject['production']['api'].to_s
      assert_equal '~> 0.1', subject['staging']['foo'].to_s
    end

  it 'can write back to the inifile (smoke test)' do
    control :production => {
      'api'    => '1.3.4',
      'worker' => '>= 1.5'
    }, :staging => {
      'dog'    => '= 1.2.3',
      'foo'    => '~> 0.1'
    }

    subject = AptControl::ControlFile.new(control_file, logger)
    FileUtils.rm(control_file)
    subject.write
    inifile = IniFile.load(control_file)

    assert inifile['production']

    # assert order is correct
    assert_equal ['api', 'worker'], inifile['production'].keys

    # assert values are correct
    assert_equal '= 1.3.4', inifile['production']['api']
    assert_equal '>= 1.5', inifile['production']['worker']

    # now for staging
    assert inifile['staging']
    assert_equal ['dog', 'foo'], inifile['staging'].keys

    assert_equal '= 1.2.3', inifile['staging']['dog']
    assert_equal '~> 0.1', inifile['staging']['foo']
  end

  it 'can read in an inifile, change a rule, then write it again' do
    control 'foo' => { 'bar' => '~> 1.5.3' }
    subject = AptControl::ControlFile.new(control_file, logger)
    assert_equal '~> 1.5.3', subject['foo']['bar'].restriction_string

    subject['foo']['bar'].constraint = '>= 6.3'

    subject.write
    subject.reload!

    subject['foo']['bar'].constraint = '>= 6.3'
  end

  it 'barfs if you try to set a bad restriction' do
    control 'foo' => { 'bar' => '~> 1.5.3' }
    subject = AptControl::ControlFile.new(control_file, logger)

    assert_raises RuntimeError do
      subject['foo']['bar'].constraint = '<= 6.3'
    end
  end

  it 'barfs if you try to set a bad version' do
    control 'foo' => { 'bar' => '~> 1.5.3' }
    subject = AptControl::ControlFile.new(control_file, logger)

    assert_raises RuntimeError do
      subject['foo']['bar'].constraint = '>= 6.3.4.1.3'
    end
  end

end
