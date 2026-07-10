# frozen_string_literal: true

module VibeSort
  # Configuration class for VibeSort
  # Holds provider, API key, model, and temperature settings
  class Configuration
    PROVIDERS = %i[openai anthropic gemini groq spacexai].freeze

    attr_reader :api_key, :temperature, :provider, :model

    # Initialize a new Configuration
    #
    # @param api_key [String] API key for the selected provider
    # @param temperature [Float] Temperature for the model (0.0 to 2.0).
    #   Ignored by providers whose current models do not accept it (Anthropic).
    # @param provider [Symbol, String] LLM provider: :openai (default), :anthropic, :gemini, :groq, or :spacexai
    # @param model [String, nil] Model ID override (nil uses the provider's default)
    # @raise [ArgumentError] if api_key is nil or empty, or provider is unknown
    def initialize(api_key:, temperature: 0.0, provider: :openai, model: nil)
      raise ArgumentError, "API key cannot be nil or empty" if api_key.nil? || api_key.empty?

      @provider = provider.to_s.to_sym
      raise ArgumentError, "Unknown provider: #{provider.inspect} (supported: #{PROVIDERS.join(", ")})" unless PROVIDERS.include?(@provider)

      @api_key = api_key
      @temperature = temperature
      @model = model
    end
  end
end
