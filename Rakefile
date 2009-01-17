require 'rubygems'
require 'hoe'
require './lib/edl.rb'

# Disable spurious warnings when running tests, ActiveMagic cannot stand -w
Hoe::RUBY_FLAGS.replace ENV['RUBY_FLAGS'] || "-I#{%w(lib test).join(File::PATH_SEPARATOR)}" + 
  (Hoe::RUBY_DEBUG ? " #{RUBY_DEBUG}" : '')

Hoe.new('edl', EDL::VERSION) do |p|
  p.rubyforge_name = 'wiretap'
  p.developer('Julik', 'me@julik.nl')
  p.extra_deps << "flexmock" << "timecode" << "test-spec"
  p.remote_rdoc_dir = 'edl'
end

task "specs" do
  `specrb test/* --rdox > SPECS.txt`
end