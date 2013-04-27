require 'tmpdir'
require 'minitest/autorun'
require 'minitest/spec'
require 'apt_control'
#require 'fileutils'

puts 'lol'

describe 'apt_control status (smoke tests)' do

  before do
    @working_dir = Dir.mktmpdir

    Dir.mkdir(apt_site_dir)
    Dir.mkdir(File.join(apt_site_dir, 'conf'))
    Dir.mkdir(build_archive_dir)

    Dir['data/packages/*'].each do |fname|
      FileUtils.cp(fname, build_archive_dir)
    end
  end

  after do
    FileUtils.rm_r(@working_dir) if File.directory?(@working_dir)
  end

  let :build_archive_dir do
    @build_archive_dir ||= begin
      File.join(@working_dir, 'builds')
    end
  end

  let :apt_site_dir do
    File.join(@working_dir, 'apt')
  end

  let :apt_config_file do
    File.join(apt_site_dir, 'conf', 'distributions')
  end

  let :control_file do
    File.join(@working_dir, 'control.ini')
  end

  def write_control_ini(string)
    File.open(control_file, 'w') {|f| f.write(string) }
  end

  def write_reprepro_config(string)
    File.open(apt_config_file, 'w') {|f| f.write(string) }
  end

  def include(codename, package, version)
    @exec = AptControl::Exec.new
    changes_file = "data/packages/#{package}_#{version}_amd64.changes"
    raise "#{changes_file} does not exist" unless File.exists?(changes_file)
    @exec.exec("reprepro -b #{apt_site_dir} --ignore=wrongdistribution include #{codename} #{changes_file}")
  end

  def run_apt_control(cmd)
    @exec = AptControl::Exec.new
    begin
      @exec.exec("ruby -rrubygems -Ilib bin/apt_control " + cmd)
    rescue AptControl::Exec::UnexpectedExitStatus => e

      fail(e.message + "\n" + e.stderr)
    end
  end

  def assert_last_stdout_include(line)
    assert @exec.last_stdout.include?(line), "line:#{line}\n  not in \n#{@exec.last_stdout}"
  end

  it 'dumps out the state of all the packages and all the distributions' do
    write_control_ini %Q{
[production]
web-ui = "= 1.1.1"
api    = "= 0.5.1"
worker = "= 0.5.5-6"

[staging]
web-ui = "~> 1.1"
api    = "~> 0.5"
worker = "~> 0.5"

[testing]
web-ui = ">= 1.0"
api    = ">= 0.4"
worker = ">= 0.5"
}

    write_reprepro_config %Q{
Codename: production
Architectures: amd64 source
Components: misc

Codename: staging
Architectures: amd64 source
Components: misc

Codename: testing
Architectures: amd64 source
Components: misc
}

    include 'production', 'web-ui', '1.1.1'
    include 'production', 'api', '0.5.1-3'
    include 'production', 'worker', '0.5.5-5'
    include 'staging', 'web-ui', '1.0.6-1'

    run_apt_control "-o build_archive_dir=#{build_archive_dir} -o control_file=#{control_file} -o apt_site_dir=#{apt_site_dir} status --machine-readable"

    assert_last_stdout_include 'production web-ui (= 1.1.1) .S included=1.1.1 available=1.0.6-1, 1.1.0, 1.1.1'
    assert_last_stdout_include 'production api (= 0.5.1) US included=0.5.1-3 available=0.5.0, 0.5.1-3, 0.5.1-4'
    assert_last_stdout_include 'production worker (= 0.5.5-6) .. included=0.5.5-5 available=0.5.5-5'
    assert_last_stdout_include 'staging web-ui (~> 1.1) U. included=1.0.6-1 available=1.0.6-1, 1.1.0, 1.1.1'
  end
end
