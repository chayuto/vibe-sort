# frozen_string_literal: true

module VibeSort
  module Providers
    # Adapter for the Anthropic Messages API
    #
    # Uses structured outputs (output_config.format with a JSON schema) so the
    # model is guaranteed to return the { "sorted_array": [...] } shape.
    #
    # Note: current Claude models (Opus 4.7+) reject the temperature parameter,
    # so config.temperature is not forwarded to this provider.
    class Anthropic < Base
      ENDPOINT = "https://api.anthropic.com/v1/messages"
      DEFAULT_MODEL = "claude-opus-4-8"
      API_VERSION = "2023-06-01"
      MAX_TOKENS = 4096

      OUTPUT_SCHEMA = {
        type: "object",
        properties: {
          sorted_array: {
            type: "array",
            items: { anyOf: [{ type: "number" }, { type: "string" }] }
          }
        },
        required: ["sorted_array"],
        additionalProperties: false
      }.freeze

      private

      def provider_name
        "Anthropic"
      end

      def endpoint
        ENDPOINT
      end

      def headers
        {
          "x-api-key" => config.api_key,
          "anthropic-version" => API_VERSION
        }
      end

      def build_payload(array)
        {
          model: model,
          max_tokens: MAX_TOKENS,
          system: SYSTEM_PROMPT,
          output_config: { format: { type: "json_schema", schema: OUTPUT_SCHEMA } },
          messages: [
            { role: "user", content: user_prompt(array) }
          ]
        }
      end

      def extract_content(response)
        blocks = response.body["content"]
        return nil unless blocks.is_a?(Array)

        text_block = blocks.find { |block| block.is_a?(Hash) && block["type"] == "text" }
        text_block && text_block["text"]
      end
    end
  end
end
