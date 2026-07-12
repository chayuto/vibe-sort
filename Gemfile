# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in vibe-sort.gemspec
gemspec

gem "rake", "~> 13.4"

group :development, :test do
  gem "pry", "~> 0.14"
  # public_suffix 7.x (via webmock -> addressable) requires Ruby >= 3.2;
  # keep the dev bundle installable on Ruby 3.0/3.1, which the gem supports
  gem "public_suffix", "< 7"
  gem "rspec", "~> 3.0"
  gem "rubocop", "~> 1.21"
  gem "webmock", "~> 3.18"
end
