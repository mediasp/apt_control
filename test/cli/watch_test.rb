require 'test/helpers'

describe 'apt_control watch' do
  include CLIHelper

  before do
    setup_dirs
    with_default_reprepro_config
  end

  let(:pidfile) do
    File.join(@working_dir, "pidfile")
  end

  after do
    kill_watch_daemon
  end

  def kill_watch_daemon
    if File.exists?(pidfile)
      pid = File.read(pidfile)
      `ps #{pid}`
      if $? == 0
        Process.kill("TERM", pid.to_i)
      else
        $stderr.puts("hmm, pidfile but no process running")
      end
    end
  end

  def log_file
    File.join(@working_dir, 'logfile')
  end

  def wait_for_output(line)
    timeout_secs = 5
    start = Time.now.to_i
    while Time.now.to_i < (start + timeout_secs)
      string = File.exists?(log_file) && File.read(log_file) || ''
      return if string.split("\n").find {|l| l.index(line) }
      sleep 0.1
    end

    string = File.exists?(log_file) && File.read(log_file) || 'file does not exist'
    fail("Timeout waiting for '#{line}' to appear in\n#{string}")
  end

  it 'observes new .changes files appearing in the build directory, including them if they are upgradeable' do
    control :production => { "api" => ">= 0.5.1" }
    build 'api', '0.5.1-3'
    include 'production', 'api', '0.5.1-3'

    run_apt_control 'status -m'
    assert_last_stdout_include 'production api (>= 0.5.1) .S'

    Thread.new do
      # Even though I'm daemonizing, this never returns - assuming it is because
      # I'm reading from stdout & stderr and these are inherited by the
      # daemonized process?
      begin
        run_apt_control "-o log_file=#{log_file} watch --daemonize --pidfile=#{pidfile}"
      rescue => e
        puts(e)
        puts(e.backtrace)
      end
    end

    wait_for_output "Watching for new changes files in #{build_archive_dir}"

    build 'api', '0.5.1-4'

    wait_for_output "included package api-0.5.1-4 in production"

    # remove me?
    kill_watch_daemon

    run_apt_control 'status -m'
    assert_last_stdout_include 'production api (>= 0.5.1) .S included=0.5.1-4'
  end

  it 'observes the control file changing, reloading control rules' do
    control :production => { "api" => '= 0.5.0' }
    build 'api', '0.5.0'
    build 'api', '0.5.1-3'
    include 'production', 'api', '0.5.0'

    run_apt_control 'status -m'
    assert_last_stdout_include 'production api (= 0.5.0) .S'

    Thread.new do
      # Even though I'm daemonizing, this never returns - assuming it is because
      # I'm reading from stdout & stderr and these are inherited by the
      # daemonized process?
      begin
        run_apt_control "-o log_file=#{log_file} watch --daemonize --pidfile=#{pidfile}", :quiet => false
      rescue => e
        puts(e)
        puts(e.backtrace)
      end
    end

    wait_for_output "Watching for changes to #{control_file}"

    control :production => { "api" => "= 0.5.1-3" }, :staging => { "api" => "= 0.5.0"}

    wait_for_output "Change to control file detected..."
    wait_for_output "...rebuilt"

    wait_for_output "included package api-0.5.1-3 in production"
    wait_for_output "included package api-0.5.0 in staging"
  end
end
