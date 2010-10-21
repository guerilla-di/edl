require 'rubygems'
require 'hoe'
require './lib/edl.rb'

# Disable spurious warnings when running tests, ActiveMagic cannot stand -w
Hoe::RUBY_FLAGS.replace ENV['RUBY_FLAGS'] || "-I#{%w(lib test).join(File::PATH_SEPARATOR)}" + 
  (Hoe::RUBY_DEBUG ? " #{RUBY_DEBUG}" : '')
  
Hoe.spec('edl') do | p |
  p.version = EDL::VERSION
  p.extra_deps = {"flexmock" => ">=0", "timecode" => ">=0.1.9", "test-spec" => ">=0"}
  p.rubyforge_name = 'guerilla-di'
  p.developer('Julik Tarkhanov', 'me@julik.nl')
end

task "specs" do
  `specrb test/* --rdox > SPECS.txt`
end