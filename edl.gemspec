# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{edl}
  s.version = "0.0.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Julik Tarkhanov"]
  s.date = %q{2009-09-21}
  s.description = %q{Work with EDL files from Ruby http://en.wikipedia.org/wiki/Edit_decision_list}
  s.email = ["me@julik.nl"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt", "SPECS.txt"]
  s.files = ["History.txt", "Manifest.txt", "README.txt", "Rakefile", "SPECS.txt", "edl.gemspec", "illustr/edl-explain.ai", "lib/edl.rb", "lib/edl/cutter.rb", "lib/edl/event.rb", "lib/edl/grabber.rb", "lib/edl/parser.rb", "lib/edl/timewarp.rb", "lib/edl/transition.rb", "test/samples/45S_SAMPLE.EDL", "test/samples/FCP_REVERSE.EDL", "test/samples/REVERSE.EDL", "test/samples/SIMPLE_DISSOLVE.EDL", "test/samples/SPEEDUP_AND_FADEOUT.EDL", "test/samples/SPEEDUP_REVERSE_AND_FADEOUT.EDL", "test/samples/SPLICEME.EDL", "test/samples/TIMEWARP.EDL", "test/samples/TIMEWARP_HALF.EDL", "test/samples/TRAILER_EDL.edl", "test/test_edl.rb"]
  s.has_rdoc = true
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{guerilla-di}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{Work with EDL files from Ruby http://en.wikipedia.org/wiki/Edit_decision_list}
  s.test_files = ["test/test_edl.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<test_spec>, [">= 0"])
      s.add_runtime_dependency(%q<timecode>, [">= 0.1.9"])
      s.add_runtime_dependency(%q<flexmock>, [">= 0"])
      s.add_development_dependency(%q<hoe>, [">= 2.3.3"])
    else
      s.add_dependency(%q<test_spec>, [">= 0"])
      s.add_dependency(%q<timecode>, [">= 0.1.9"])
      s.add_dependency(%q<flexmock>, [">= 0"])
      s.add_dependency(%q<hoe>, [">= 2.3.3"])
    end
  else
    s.add_dependency(%q<test_spec>, [">= 0"])
    s.add_dependency(%q<timecode>, [">= 0.1.9"])
    s.add_dependency(%q<flexmock>, [">= 0"])
    s.add_dependency(%q<hoe>, [">= 2.3.3"])
  end
end
