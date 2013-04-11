lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'apt_control/version'

Gem::Specification.new do |s|
  s.name        = "apt_control"
  s.version     = AptControl::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Nick Griffiths"]
  s.email       = ["nicobrevin@gmail.com"]
  s.homepage    = "http://github.com/playlouder/apt_control"
  s.summary     = "Automatically manage an apt repository that changes a lot"

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency "popen4"
  s.add_dependency "climate"
  s.add_dependency "inifile"

  s.add_development_dependency "rspec"

  s.files        = Dir.glob("{bin,lib}/**/*")
  s.executables  = ['apt_control']
  s.require_path = 'lib'
end