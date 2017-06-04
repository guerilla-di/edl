# frozen_string_literal: true

require 'rubygems'
require './lib/edl.rb'
require 'rake/testtask'

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)

  task default: :spec
rescue LoadError
  # no rspec available
end
