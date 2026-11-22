# frozen_string_literal: true

module VibeSort
  # Configuration class for VibeSort
  # Holds provider, API key, model, temperature, and extra request parameters
  class Configuration
    PROVIDERS = %i[openai anthropic gemini groq spacexai openrouter].freeze

    attr_reader :api_key, :temperature, :provider, :model, :extra_params, :base_url, :gateway, :jev_options

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
    # @param base_url [String, nil] System One gateway root (Jev only)
    # @param jev_options [Hash] System One options (strategy:, long_context:, ...); see Providers::Jev
    # @raise [ArgumentError] if api_key is nil or empty, or provider is unknown
    # @raise [ConfigurationError] for contradictory options (e.g. strategy: with a generative provider)
    def initialize(api_key: nil, temperature: 0.0, provider: nil, model: nil, extra_params: {}, base_url: nil, jev_options: {})
      validate_provider_name!(provider)
      resolution = ProviderResolver.resolve(api_key: api_key, provider: provider, model: model,
                                            strategy: jev_options[:strategy], base_url: base_url)
      @temperature = temperature
      @extra_params = extra_params
      @jev_options = jev_options
      apply(resolution, provider, model)
    end

    # @return [Boolean] true when routed to TypeSafe System One (Jev)
    def jev?
      provider == :jev
    end

    private

    def apply(resolution, requested_provider, model)
      @api_key = resolution.api_key
      @base_url = resolution.base_url
      @gateway = resolution.gateway
      if resolution.jev?
        @provider = :jev
        @model = resolution.model
      else
        @provider = resolve_provider(requested_provider, @api_key)
        @model = model
      end
    end

    def validate_provider_name!(provider)
      return if provider.nil?

      explicit = provider.to_s.to_sym
      return if PROVIDERS.include?(explicit) || ProviderResolver::JEV_PROVIDERS.include?(explicit)

      raise ArgumentError, "Unknown provider: #{provider.inspect} (supported: #{(PROVIDERS + ProviderResolver::JEV_PROVIDERS).join(", ")})"
    end

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
      warn "vibe-sort: api_key format suggests :#{detected} but provider is :#{explicit}" if detected && detected != explicit
      explicit
    end
  end
end
