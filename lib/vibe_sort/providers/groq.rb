# frozen_string_literal: true

module VibeSort
  module Providers
    # Adapter for the Groq API (OpenAI-compatible Chat Completions)
    class Groq < OpenAI
      ENDPOINT = "https://api.groq.com/openai/v1/chat/completions"
      DEFAULT_MODEL = "llama-3.3-70b-versatile"

      private

      def provider_name
        "Groq"
      end

      def endpoint
        ENDPOINT
      end
    end
  end
end
