# frozen_string_literal: true

require_relative "lib/vibe_sort/version"

Gem::Specification.new do |spec|
  spec.name = "vibe-sort"
  spec.version = VibeSort::VERSION
  spec.authors = ["Chayut Orapinpatipat"]
  spec.email = ["chayut_o@hotmail.com"]

  spec.summary = "AI-powered array sorting using OpenAI's GPT models"
  spec.description = "A proof-of-concept Ruby gem that sorts number arrays by leveraging the OpenAI Chat Completions API. Demonstrates how AI can be used for computational tasks."
  spec.homepage = "https://github.com/chayuto/vibe-sort"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/chayuto/vibe-sort"
  spec.metadata["changelog_uri"] = "https://github.com/chayuto/vibe-sort/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "faraday", "~> 2.0"
end
