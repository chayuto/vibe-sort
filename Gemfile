# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in vibe-sort.gemspec
gemspec

gem "rake", "~> 13.4"
# json 3.x (pulled in by rubocop 1.92) makes the provider specs fail with an arity error; root cause not yet investigated
gem "json", "< 3"

group :development, :test do
  gem "pry", "~> 0.16"
  # public_suffix 7.x (via webmock -> addressable) requires Ruby >= 3.2;
  # keep the dev bundle installable on Ruby 3.0/3.1, which the gem supports
  gem "public_suffix", "< 7"
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.92"
  gem "webmock", "~> 3.40"
end
