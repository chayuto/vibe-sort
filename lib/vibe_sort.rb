# frozen_string_literal: true

require "faraday"
require "json"

require_relative "vibe_sort/version"
require_relative "vibe_sort/error"
require_relative "vibe_sort/key_detector"
require_relative "vibe_sort/settings"
require_relative "vibe_sort/result"
require_relative "vibe_sort/provider_resolver"
require_relative "vibe_sort/configuration"
require_relative "vibe_sort/providers/base"
require_relative "vibe_sort/providers/openai"
require_relative "vibe_sort/providers/anthropic"
require_relative "vibe_sort/providers/gemini"
require_relative "vibe_sort/providers/groq"
require_relative "vibe_sort/providers/space_x_ai"
require_relative "vibe_sort/providers/open_router"
require_relative "vibe_sort/system_one/serializer"
require_relative "vibe_sort/system_one/client"
require_relative "vibe_sort/system_one/strategies/base"
require_relative "vibe_sort/system_one/strategies/choice_sort"
require_relative "vibe_sort/system_one/strategies/score_sort"
require_relative "vibe_sort/system_one/strategies/noul_sort"
require_relative "vibe_sort/system_one/strategies/bogo_sort"
require_relative "vibe_sort/providers/jev"
require_relative "vibe_sort/sorter"
require_relative "vibe_sort/client"

module VibeSort
  class Error < StandardError; end
end
