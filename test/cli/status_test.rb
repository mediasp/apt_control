require 'test/helpers'

describe 'apt_control status (smoke tests)' do
  include CLIHelper

  before do
    setup_dirs
    with_default_reprepro_config

    builds_by_blob "*"
  end

  it 'dumps out the state of all the packages and all the distributions' do
    control :production => {
      "web-ui" => "= 1.1.1",
      "api"    => "= 0.5.1",
      "worker" => "= 0.5.5-6",
    }, :staging => {
      "web-ui" => "~> 1.1",
      "api"    => "~> 0.5",
      "worker" => "~> 0.5",
    }, :testing => {
      "web-ui" => ">= 1.0",
      "api"    => ">= 0.4",
      "worker" => ">= 0.5",
    }

    include 'production', 'web-ui', '1.1.1'
    include 'production', 'api', '0.5.1-3'
    include 'production', 'worker', '0.5.5-5'
    include 'staging', 'web-ui', '1.0.6-1'

    run_apt_control "status --machine-readable"

    assert_last_stdout_include 'production web-ui (= 1.1.1) .S included=1.1.1 available=1.0.6-1, 1.1.0, 1.1.1'
    assert_last_stdout_include 'production api (= 0.5.1) US included=0.5.1-3 available=0.5.0, 0.5.1-3, 0.5.1-4'
    assert_last_stdout_include 'production worker (= 0.5.5-6) .. included=0.5.5-5 available=0.5.5-5'
    assert_last_stdout_include 'staging web-ui (~> 1.1) U. included=1.0.6-1 available=1.0.6-1, 1.1.0, 1.1.1'
  end
end
