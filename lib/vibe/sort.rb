# frozen_string_literal: true

# Compatibility shim: Bundler autorequires "vibe/sort" for a gem named
# "vibe-sort", so `gem "vibe-sort"` in a Gemfile loads the real library
# without needing an explicit `require "vibe_sort"`.
require_relative "../vibe_sort"
