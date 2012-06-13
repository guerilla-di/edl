require 'rubygems'
require './lib/edl.rb'
require 'jeweler'

Jeweler::Tasks.new do |gem|
  gem.version = EDL::VERSION
  gem.name = "edl"
  gem.summary = "Parser for EDL (Edit Decision List) files"
  gem.email = "me@julik.nl"
  gem.homepage = "http://guerilla-di.org/edl"
  gem.authors = ["Julik Tarkhanov"]
  
  # Do not package invisibles
  gem.files.exclude ".*"
end

Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
desc "Run all tests"
Rake::TestTask.new("test") do |t|
  t.libs << "test"
  t.pattern = 'test/**/test_*.rb'
  t.verbose = true
end

task :default => [ :test ]
