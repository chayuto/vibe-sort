# frozen_string_literal: true

module VibeSort
  module Providers
    # Adapter for the OpenRouter API (OpenAI-compatible Chat Completions)
    class OpenRouter < OpenAI
      ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"
      DEFAULT_MODEL = "openai/gpt-4o-mini"

      private

      def provider_name
        "OpenRouter"
      end

      def endpoint
        ENDPOINT
      end

      # Optional attribution headers recommended by OpenRouter
      def headers
        super.merge(
          "HTTP-Referer" => "https://github.com/chayuto/vibe-sort",
          "X-Title" => "vibe-sort"
        )
      end
    end
  end
end
