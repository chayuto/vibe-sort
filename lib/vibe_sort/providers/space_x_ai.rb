# frozen_string_literal: true

module VibeSort
  module Providers
    # Adapter for the SpaceXAI (xAI) Grok API (OpenAI-compatible Chat Completions)
    class SpaceXAI < OpenAI
      ENDPOINT = "https://api.x.ai/v1/chat/completions"
      DEFAULT_MODEL = "grok-4"

      private

      def provider_name
        "SpaceXAI"
      end

      def endpoint
        ENDPOINT
      end
    end
  end
end
