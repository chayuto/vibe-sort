# frozen_string_literal: true

module VibeSort
  # Configuration class for VibeSort
  # Holds provider, API key, model, temperature, and extra request parameters
  class Configuration
    PROVIDERS = %i[openai anthropic gemini groq spacexai openrouter].freeze

    attr_reader :api_key, :temperature, :provider, :model, :extra_params

    # Initialize a new Configuration
    #
    # @param api_key [String] API key for the selected provider
    # @param temperature [Float] Temperature for the model (0.0 to 2.0).
    #   Ignored by providers whose current models do not accept it (Anthropic).
    # @param provider [Symbol, String, nil] LLM provider: :openai, :anthropic, :gemini,
    #   :groq, :spacexai, or :openrouter. When nil (default), the provider is inferred
    #   from the api_key prefix, falling back to :openai for unrecognized keys.
    # @param model [String, nil] Model ID override (nil uses the provider's default)
    # @param extra_params [Hash] Provider-native request parameters deep-merged into
    #   the payload last, so they can override anything (e.g. { max_tokens: 100 })
    # @raise [ArgumentError] if api_key is nil or empty, or provider is unknown
    def initialize(api_key:, temperature: 0.0, provider: nil, model: nil, extra_params: {})
      raise ArgumentError, "API key cannot be nil or empty" if api_key.nil? || api_key.empty?

      @provider = resolve_provider(provider, api_key)
      @api_key = api_key
      @temperature = temperature
      @model = model
      @extra_params = extra_params
    end

    private

    # Resolve the provider: explicit argument wins (with a non-fatal warning if the
    # key prefix suggests a different provider); otherwise infer from the key prefix,
    # defaulting to :openai for unrecognized formats.
    #
    # @param provider [Symbol, String, nil] Explicit provider argument, if any
    # @param api_key [String] API key used for prefix inference
    # @return [Symbol] Resolved provider
    # @raise [ArgumentError] if an explicit provider is unknown
    def resolve_provider(provider, api_key)
      detected = KeyDetector.detect(api_key)
      return detected || :openai if provider.nil?

      explicit = provider.to_s.to_sym
      raise ArgumentError, "Unknown provider: #{provider.inspect} (supported: #{PROVIDERS.join(", ")})" unless PROVIDERS.include?(explicit)

      warn "vibe-sort: api_key format suggests :#{detected} but provider is :#{explicit}" if detected && detected != explicit
      explicit
    end
  end
end
