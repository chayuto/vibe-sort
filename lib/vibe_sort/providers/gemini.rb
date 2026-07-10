# frozen_string_literal: true

module VibeSort
  module Providers
    # Adapter for the Google Gemini API (generateContent)
    class Gemini < Base
      BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"
      DEFAULT_MODEL = "gemini-2.5-flash"

      private

      def provider_name
        "Gemini"
      end

      # The Gemini endpoint embeds the model ID in the URL path
      def endpoint
        "#{BASE_URL}/#{model}:generateContent"
      end

      def headers
        { "x-goog-api-key" => config.api_key }
      end

      def build_payload(array)
        {
          systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
          contents: [
            { role: "user", parts: [{ text: user_prompt(array) }] }
          ],
          generationConfig: {
            temperature: config.temperature,
            responseMimeType: "application/json"
          }
        }
      end

      def extract_content(response)
        response.body.dig("candidates", 0, "content", "parts", 0, "text")
      end
    end
  end
end
