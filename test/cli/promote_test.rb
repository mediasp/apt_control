require 'test/helpers'

describe 'apt_control set' do
  include CLIHelper

  before do
    setup_dirs
    with_default_reprepro_config
  end

  describe 'with perfect conditions' do
    before do
      control production: { 'api' => '0.5.0'}, staging: { 'api' => '~> 0.5'}
      build 'api', '0.5.0'
      build 'api', '0.5.1-3'
      include 'production', 'api', '0.5.0'
      include 'staging',    'api', '0.5.1-3'
    end

    it 'will update the control file to want the version included in the source distribution' do
      run_apt_control 'promote staging production api'
      run_apt_control 'status -m'

      assert_last_stdout_include 'staging api (~> 0.5) .S included=0.5.1-3'
      assert_last_stdout_include 'production api (= 0.5.1-3) I.'
    end

    it 'barfs if the destination does not exist' do
      run_apt_control 'promote staging prod api', :status => 1
      assert_last_stderr_include 'destination distribution \'prod\' does not exist'
    end

    it 'barfs if the source does not exist' do
      run_apt_control 'promote stage production api', :status => 1
      assert_last_stderr_include 'source distribution \'stage\' does not exist'
    end

    it 'barfs if the package does not exist in the source' do
      run_apt_control 'promote staging production worker', :status => 1
      assert_last_stderr_include 'package \'worker\' does not exist in distribution \'staging\''
    end
  end

  describe 'package does not exist in the destination distribution' do
    before do
      control production: { }, staging: { 'api' => '~> 0.5' }
      build 'api', '0.5.0'
      build 'api', '0.5.1-3'
      include 'staging', 'api', '0.5.1-3'
    end

    it 'creates an entry in the control file for the package' do
      run_apt_control 'promote staging production api'
      run_apt_control 'status -m'
      assert_last_stdout_include 'staging api (~> 0.5) .S included=0.5.1-3'
      assert_last_stdout_include 'production api (= 0.5.1-3) I.'
    end
  end

  describe 'no package has been included in the source distribution' do
    before do
      control production: { 'api' => '0.5.0'}, staging: { 'api' => '~> 0.5'}
      build 'api', '0.5.0'
      build 'api', '0.5.1-3'
      include 'production', 'api', '0.5.0'
    end

    it 'barfs' do
      run_apt_control 'promote staging production api', :status => 1
      assert_last_stderr_include 'no \'api\' package included in \'staging\' to promote'
    end
  end
end
