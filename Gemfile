# -*- ruby -*-
source 'https://rubygems.org'

gem "timecode"

group :development do
  gem 'shoulda-context'
  gem "test-unit", :require => "test/unit"
  gem "jeweler"
  gem "rake"
  flexmock_ver = (RUBY_VERSION > "1.8") ? "~> 1.3.2" : "~> 0.8"
  gem "flexmock", flexmock_ver, :require => %w( flexmock flexmock/test_unit )
end