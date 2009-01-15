require 'rubygems'
require 'hoe'
require './lib/edl.rb'

Hoe.new('edl', EDL::VERSION) do |p|
  p.rubyforge_name = 'wiretap'
  p.developer('Julik', 'me@julik.nl')
  p.extra_deps << "flexmock" << "timecode" << "test-spec"
  p.remote_rdoc_dir = 'edl'
end

task "specs" do
  `specrb test/* --rdox > SPECS.txt`
end