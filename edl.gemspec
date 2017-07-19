# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'edl/version'

Gem::Specification.new do |s|
  s.required_rubygems_version = ">= 1.2.0"

  s.name = 'edl'
  s.version = EDL::VERSION
  s.authors = ['Julik Tarkhanov', 'Philipp Großelfinger']
  s.date = '2014-03-24'
  s.email = 'me@julik.nl'
  s.extra_rdoc_files = [
    'README.md'
  ]

  # Prevent pushing this gem to RubyGemspec.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if s.respond_to?(:metadata)
    s.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushespec."
  end
  
  s.files         = `git ls-files -z`.split("\x0")
  s.bindir        = 'exe'
  s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.homepage = 'http://guerilla-di.org/edl'
  s.require_paths = ['lib']
  s.rubygems_version = '2.0.3'
  s.summary = 'Parser for EDL (Edit Decision List) files'

  s.add_runtime_dependency 'timecode', '>= 0'
  s.add_development_dependency 'rake', '>= 0'
  s.add_development_dependency 'rspec', '~> 3.5'
end
