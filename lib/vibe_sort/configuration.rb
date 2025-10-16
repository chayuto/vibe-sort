# frozen_string_literal: true

module VibeSort
  # Configuration class for VibeSort
  # Holds API key and temperature settings
  class Configuration
    attr_reader :api_key, :temperature

    # Initialize a new Configuration
    #
    # @param api_key [String] OpenAI API key
    # @param temperature [Float] Temperature for the model (0.0 to 2.0)
    # @raise [ArgumentError] if api_key is nil or empty
    def initialize(api_key:, temperature: 0.0)
      raise ArgumentError, "API key cannot be nil or empty" if api_key.nil? || api_key.empty?

      @api_key = api_key
      @temperature = temperature
    end
  end
end
