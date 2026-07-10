# frozen_string_literal: true

module VibeSort
  module Providers
    # Adapter for the OpenAI Chat Completions API
    class OpenAI < Base
      ENDPOINT = "https://api.openai.com/v1/chat/completions"
      DEFAULT_MODEL = "gpt-4o-mini"

      private

      def provider_name
        "OpenAI"
      end

      def endpoint
        ENDPOINT
      end

      def headers
        { "Authorization" => "Bearer #{config.api_key}" }
      end

      def build_payload(array)
        {
          model: model,
          temperature: config.temperature,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: user_prompt(array) }
          ]
        }
      end

      def extract_content(response)
        response.body.dig("choices", 0, "message", "content")
      end
    end
  end
end
