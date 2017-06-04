# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'edl/version'

Gem::Specification.new do |s|
  s.name = 'edl'
  s.version = EDL::VERSION

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.authors = ['Julik Tarkhanov']
  s.date = '2014-03-24'
  s.email = 'me@julik.nl'
  s.extra_rdoc_files = [
    'README.rdoc'
  ]

  s.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.bindir        = 'exe'
  s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.homepage = 'http://guerilla-di.org/edl'
  s.require_paths = ['lib']
  s.rubygems_version = '2.0.3'
  s.summary = 'Parser for EDL (Edit Decision List) files'

  if s.respond_to? :specification_version
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0')
      s.add_runtime_dependency 'timecode', '>= 0'
      s.add_development_dependency 'rake', '>= 0'
      s.add_development_dependency 'rspec', '~> 3.5'
    else
      s.add_dependency 'timecode', '>= 0'
      s.add_dependency 'rake', '>= 0'
    end
  else
    s.add_dependency 'timecode', '>= 0'
    s.add_dependency 'rake', '>= 0'
  end
end
