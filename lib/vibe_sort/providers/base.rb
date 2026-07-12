# frozen_string_literal: true

module VibeSort
  module Providers
    # Base class for LLM provider adapters.
    #
    # Holds everything that is provider-agnostic: the sorting prompt, the
    # Faraday connection plumbing, and validation of the returned array.
    # Subclasses implement the provider-specific hooks: +provider_name+,
    # +endpoint+, +headers+, +build_payload+, and +extract_content+.
    class Base
      SYSTEM_PROMPT = "You are an assistant that only sorts arrays. The array may contain numbers and strings. Sort the array in ascending order. Follow standard sorting rules: numbers should come before strings, and string sorting should be case-sensitive. Return a JSON object with a single key 'sorted_array' containing the sorted elements."

      attr_reader :config

      # @param config [VibeSort::Configuration] Configuration object
      def initialize(config)
        @config = config
      end

      # Perform the sorting operation via the provider's API
      #
      # @param array [Array] Array of numbers and/or strings to sort
      # @return [Hash] Result hash with :success and :sorted_array keys
      # @raise [VibeSort::ApiError] if the API request fails
      def perform(array)
        response = connection.post do |req|
          req.body = deep_merge(build_payload(array), config.extra_params)
        end

        handle_response(response)
      end

      private

      # Merge the user's extra_params into the adapter payload last, so they can
      # override anything (response_format, temperature, even model). Nested
      # hashes merge recursively (e.g. Gemini's generationConfig); arrays and
      # scalars replace.
      #
      # @param base [Hash] Adapter-built payload
      # @param extra [Hash] User-supplied provider-native parameters
      # @return [Hash] Merged payload
      def deep_merge(base, extra)
        base.merge(extra) do |_key, old_val, new_val|
          old_val.is_a?(Hash) && new_val.is_a?(Hash) ? deep_merge(old_val, new_val) : new_val
        end
      end

      # Model to use: explicit override from config, or the provider default
      #
      # @return [String] Model ID
      def model
        config.model || self.class::DEFAULT_MODEL
      end

      # @param array [Array] Array to sort
      # @return [String] User prompt sent to the model
      def user_prompt(array)
        "Please sort this array: #{array.to_json}"
      end

      # @return [Faraday::Connection] Faraday connection object
      def connection
        @connection ||= Faraday.new(url: endpoint) do |f|
          f.request :json  # Encodes request body as JSON
          f.response :json # Decodes response body as JSON
          headers.each { |name, value| f.headers[name] = value }
          f.headers["Content-Type"] = "application/json"
          f.adapter Faraday.default_adapter
        end
      end

      # @param response [Faraday::Response] HTTP response
      # @return [Hash] Result hash
      # @raise [VibeSort::ApiError] if response is invalid or parsing fails
      def handle_response(response)
        unless response.success?
          error_message = extract_error_message(response)
          raise ApiError.new("#{provider_name} API error: #{error_message}", response)
        end

        parse_sorted_array(response)
      end

      # Extract error message from failed response. Works for all three
      # providers: OpenAI, Anthropic, and Gemini all return an "error"
      # object with a "message" key on failure.
      #
      # @param response [Faraday::Response] HTTP response
      # @return [String] Error message
      def extract_error_message(response)
        return "Unknown error" unless response.body.is_a?(Hash)

        response.body.dig("error", "message") || "HTTP #{response.status}"
      rescue StandardError
        "HTTP #{response.status}"
      end

      # Parse the sorted array from the API response
      #
      # @param response [Faraday::Response] HTTP response
      # @return [Hash] Success result with sorted array
      # @raise [VibeSort::ApiError] if parsing fails or validation fails
      def parse_sorted_array(response)
        content = extract_content(response)
        raise ApiError.new("Invalid response structure", response) if content.nil?

        parsed_content = JSON.parse(content)
        sorted_array = parsed_content["sorted_array"]

        validate_sorted_array!(sorted_array)

        { success: true, sorted_array: sorted_array }
      rescue JSON::ParserError => e
        raise ApiError.new("Failed to parse JSON response: #{e.message}", response)
      end

      # Validate that the sorted array is valid
      #
      # @param sorted_array [Object] Parsed sorted array
      # @raise [VibeSort::ApiError] if validation fails
      def validate_sorted_array!(sorted_array)
        raise ApiError, "Response does not contain a valid 'sorted_array'" unless sorted_array.is_a?(Array)

        return if sorted_array.all? { |item| item.is_a?(Numeric) || item.is_a?(String) }

        raise ApiError, "Sorted array contains invalid values (must be numbers or strings)"
      end

      # --- Provider-specific hooks ---

      # @return [String] Human-readable provider name used in error messages
      def provider_name
        raise NotImplementedError
      end

      # @return [String] Full URL of the API endpoint
      def endpoint
        raise NotImplementedError
      end

      # @return [Hash] Provider-specific HTTP headers (auth etc.)
      def headers
        raise NotImplementedError
      end

      # @param array [Array] Array to sort
      # @return [Hash] Provider-specific request payload
      def build_payload(array)
        raise NotImplementedError
      end

      # @param response [Faraday::Response] HTTP response
      # @return [String, nil] Raw JSON text produced by the model
      def extract_content(response)
        raise NotImplementedError
      end
    end
  end
end
