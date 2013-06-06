require 'tmpdir'
require 'minitest/autorun'
require 'minitest/spec'
require 'apt_control'
require 'inifile'

module CLIHelper

  def self.included(other_mod)
    other_mod.instance_eval do
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
    end
  end

  def setup_dirs
    @working_dir = Dir.mktmpdir

    Dir.mkdir(apt_site_dir)
    Dir.mkdir(File.join(apt_site_dir, 'conf'))
    Dir.mkdir(build_archive_dir)
  end

  def write_reprepro_config(string)
    File.open(apt_config_file, 'w') {|f| f.write(string) }
  end

  def write_control_ini(string)
    File.open(control_file, 'w') {|f| f.write(string) }
  end

  def build(package, version)
    builds_by_blob "#{package}*#{version}*"
  end

  def control(hash)

    # weird escaping problem with inifile writing
    hash.each do |s, h|
      h.each do |k, v|
        h[k] = '"' + v + '"'
      end
    end

    IniFile.new.tap do |inifile|
      inifile.merge!(hash)
      # apply filename after new to stop it reading old contents
      inifile.filename = control_file

      inifile.write
    end
  end

  def builds_by_blob(blob)
    Dir["data/packages/#{blob}"].each do |fname|
      FileUtils.cp(fname, build_archive_dir)
    end
  end

  def include(codename, package, version)
    @exec = AptControl::Exec.new
    changes_file = "data/packages/#{package}_#{version}_amd64.changes"
    raise "#{changes_file} does not exist" unless File.exists?(changes_file)
    begin
      @exec.exec("reprepro -b #{apt_site_dir} --ignore=wrongdistribution include #{codename} #{changes_file}")
    rescue AptControl::Exec::UnexpectedExitStatus => e
      puts e.stderr
      raise
    end
  end

  def run_apt_control(cmd, options={})
    @exec = AptControl::Exec.new(options)
    opts = {
      build_archive_dir: build_archive_dir,
      control_file:      control_file,
      apt_site_dir:      apt_site_dir,
      # there is some problem with inotify under tests - the events don't seem
      # to be fired - maybe because the (original) parent process made the
      # changes?
      disable_inotify:   true
    }.map {|k,v| "-o #{k}=#{v}" }.join(' ')
    begin
      cmd = "ruby -rrubygems -Ilib bin/apt_control #{opts} " + cmd
      @exec.exec(cmd)
    rescue AptControl::Exec::UnexpectedExitStatus => e

      fail(e.message + "\n" + e.stderr)
    end
  end

  def assert_last_stdout_include(line)
    assert @exec.last_stdout.include?(line), "line:#{line}\n  not in \n#{@exec.last_stdout}"
  end

  def with_default_reprepro_config
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

  end
end

