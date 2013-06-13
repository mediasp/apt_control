require 'test/helpers'

describe 'apt_control include' do
  include CLIHelper

  before do
    setup_dirs
    with_default_reprepro_config
  end

  it 'does nothing if there are no packages to include' do
    build   'worker', '0.5.5-5'
    include 'production', 'worker', '0.5.5-5'
    control production: { worker: '= 0.5.5' }

    run_apt_control 'include'
  end

  it 'will print out what it wants to do if there are packages to include in dry run mode' do
    build 'api', '0.5.0'
    build 'api', '0.5.1-3'
    include 'production', 'api', '0.5.0'
    control production: { api: '~> 0.5' }

    run_apt_control 'include --noop'

    assert_last_stdout_include "production api 0.5.0 => 0.5.1-3"
  end

  it 'will include a new package if it is includeable' do
    build 'api', '0.5.0'
    build 'api', '0.5.1-3'
    include 'production', 'api', '0.5.0'
    control production: { api: '~> 0.5' }

    run_apt_control 'include'
    run_apt_control 'status -m'

    assert_last_stdout_include "production api (~> 0.5) .S included=0.5.1-3"
  end

  it 'will not include a package if it is lower than the already included package' do
  end

  it 'will include a package if it is lower than the already included package if you specify --force' do
  end
end
