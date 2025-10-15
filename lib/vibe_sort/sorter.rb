# frozen_string_literal: true

module VibeSort
  # Sorter class handles the API call to OpenAI
  class Sorter
    OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"
    DEFAULT_MODEL = "gpt-3.5-turbo-1106"

    attr_reader :config

    # Initialize a new Sorter
    #
    # @param config [VibeSort::Configuration] Configuration object
    def initialize(config)
      @config = config
    end

    # Perform the sorting operation via OpenAI API
    #
    # @param array [Array] Array of numbers and/or strings to sort
    # @return [Hash] Result hash with :success, :sorted_array, and optional :error keys
    # @raise [VibeSort::ApiError] if the API request fails
    def perform(array)
      response = connection.post do |req|
        req.body = build_payload(array)
      end

      handle_response(response)
    end

    private

    # Build the connection to OpenAI API
    #
    # @return [Faraday::Connection] Faraday connection object
    def connection
      @connection ||= Faraday.new(url: OPENAI_API_URL) do |f|
        f.request :json  # Encodes request body as JSON
        f.response :json # Decodes response body as JSON
        f.headers["Authorization"] = "Bearer #{config.api_key}"
        f.headers["Content-Type"] = "application/json"
        f.adapter Faraday.default_adapter
      end
    end

    # Build the request payload for OpenAI API
    #
    # @param array [Array] Array to sort (numbers and/or strings)
    # @return [Hash] Request payload
    def build_payload(array)
      {
        model: DEFAULT_MODEL,
        temperature: config.temperature,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: "You are an assistant that only sorts arrays. The array may contain numbers and strings. Sort the array in ascending order. Follow standard sorting rules: numbers should come before strings, and string sorting should be case-sensitive. Return a JSON object with a single key 'sorted_array' containing the sorted elements."
          },
          {
            role: "user",
            content: "Please sort this array: #{array.to_json}"
          }
        ]
      }
    end

    # Handle the API response
    #
    # @param response [Faraday::Response] HTTP response
    # @return [Hash] Result hash
    # @raise [VibeSort::ApiError] if response is invalid or parsing fails
    def handle_response(response)
      unless response.success?
        error_message = extract_error_message(response)
        raise ApiError.new("OpenAI API error: #{error_message}", response)
      end

      parse_sorted_array(response)
    end

    # Extract error message from failed response
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
      content = response.body.dig("choices", 0, "message", "content")
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
  end
end
