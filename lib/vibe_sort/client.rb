# frozen_string_literal: true

module VibeSort
  # Client is the main public interface for the VibeSort gem
  class Client
    attr_reader :config

    # Initialize a new VibeSort client
    #
    # @param api_key [String] API key for the selected provider
    # @param temperature [Float] Temperature for the model (default: 0.0).
    #   Ignored by providers whose current models do not accept it (Anthropic).
    # @param provider [Symbol, String] LLM provider: :openai (default), :anthropic, or :gemini
    # @param model [String, nil] Model ID override (nil uses the provider's default)
    # @raise [ArgumentError] if api_key or provider is invalid
    #
    # @example OpenAI (default provider)
    #   client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])
    #
    # @example Anthropic Claude
    #   client = VibeSort::Client.new(provider: :anthropic, api_key: ENV['ANTHROPIC_API_KEY'])
    #
    # @example Google Gemini with a custom model
    #   client = VibeSort::Client.new(provider: :gemini, api_key: ENV['GEMINI_API_KEY'], model: 'gemini-2.5-pro')
    def initialize(api_key:, temperature: 0.0, provider: :openai, model: nil)
      @config = Configuration.new(api_key: api_key, temperature: temperature, provider: provider, model: model)
    end

    # Sort an array of numbers and/or strings using the configured provider's API
    #
    # @param array [Array] Array of numbers and/or strings to sort
    # @return [Hash] Result hash with keys:
    #   - :success [Boolean] whether the operation succeeded
    #   - :sorted_array [Array] the sorted array (empty on failure)
    #   - :error [String] error message (only present on failure)
    #
    # @example Successful sort with numbers
    #   result = client.sort([5, 2, 8, 1, 9])
    #   #=> { success: true, sorted_array: [1, 2, 5, 8, 9] }
    #
    # @example Successful sort with strings
    #   result = client.sort(["banana", "Apple", "cherry"])
    #   #=> { success: true, sorted_array: ["Apple", "banana", "cherry"] }
    #
    # @example Successful sort with mixed types
    #   result = client.sort([42, "hello", 8, "world"])
    #   #=> { success: true, sorted_array: [8, 42, "hello", "world"] }
    #
    # @example Invalid input
    #   result = client.sort([1, :symbol, 3])
    #   #=> { success: false, sorted_array: [], error: "Input must be an array of numbers or strings" }
    #
    # @example API error
    #   result = client.sort([1, 2, 3]) # with invalid API key
    #   #=> { success: false, sorted_array: [], error: "OpenAI API error: Invalid API key" }
    #   # The error prefix names the configured provider (OpenAI, Anthropic, or Gemini)
    def sort(array)
      # Validate input
      unless valid_input?(array)
        return {
          success: false,
          sorted_array: [],
          error: "Input must be an array of numbers or strings"
        }
      end

      # Perform the sort via API
      sorter = Sorter.new(config)
      sorter.perform(array)
    rescue ApiError => e
      {
        success: false,
        sorted_array: [],
        error: e.message
      }
    rescue StandardError => e
      {
        success: false,
        sorted_array: [],
        error: "Unexpected error: #{e.message}"
      }
    end

    private

    # Validate that input is an array of numbers and/or strings
    #
    # @param array [Object] Input to validate
    # @return [Boolean] true if valid, false otherwise
    def valid_input?(array)
      return false unless array.is_a?(Array)
      return false if array.empty?

      array.all? { |item| item.is_a?(Numeric) || item.is_a?(String) }
    end
  end
end
