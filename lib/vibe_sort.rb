# frozen_string_literal: true

require "faraday"
require "json"

require_relative "vibe_sort/version"
require_relative "vibe_sort/error"
require_relative "vibe_sort/configuration"
require_relative "vibe_sort/providers/base"
require_relative "vibe_sort/providers/openai"
require_relative "vibe_sort/providers/anthropic"
require_relative "vibe_sort/providers/gemini"
require_relative "vibe_sort/providers/groq"
require_relative "vibe_sort/providers/space_x_ai"
require_relative "vibe_sort/sorter"
require_relative "vibe_sort/client"

module VibeSort
  class Error < StandardError; end
end
