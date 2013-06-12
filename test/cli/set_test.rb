require 'test/helpers'

describe 'apt_control set' do
  include CLIHelper

  before do
    setup_dirs
    with_default_reprepro_config

    control production: { worker: '= 0.5.5' }
  end

  it 'sets the version and writes the inifile' do
    run_apt_control 'set production worker ">= 0.6"'
    run_apt_control 'status -m'

    assert_last_stdout_include "production worker (>= 0.6)"
  end

  it 'complains if the distribution does not exist' do
    run_apt_control 'set prod worker ">= 0.6"', :status => 1
    assert_last_stderr_include "no such distribution: prod"
  end

  it 'complains if the package does not exist' do
    run_apt_control 'set production foo ">= 0.6"', :status => 1
    assert_last_stderr_include "no such package: foo"
  end

  it 'complains if the restriction is bad' do
    run_apt_control 'set production worker "gt 0.6"', :status => 1
    assert_last_stderr_include "could not set constraint:"
  end
end
