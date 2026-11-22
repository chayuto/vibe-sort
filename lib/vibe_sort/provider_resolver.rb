# frozen_string_literal: true

module VibeSort
  # Deterministic routing between the generative LLM providers and TypeSafe
  # System One (Jev), over either gateway (TypeSafe Direct or OpenRouter).
  #
  # Priority order (first match wins):
  #   1. provider: :jev/:typesafe + OpenRouter key         -> Jev via OpenRouter
  #   2. provider: :jev/:typesafe                          -> Jev via TypeSafe Direct
  #   3. OpenRouter key + a jev model id                   -> Jev via OpenRouter
  #   4. OpenRouter key + explicit strategy:               -> Jev via OpenRouter
  #   5. explicit provider, or a recognised key prefix     -> existing LLM provider
  #   6. no key, TYPESAFE_API_KEY set                      -> Jev via TypeSafe Direct
  #   7. unrecognised key + jev model or strategy:         -> Jev via TypeSafe Direct
  #   otherwise                                            -> :openai (0.4.0 behaviour)
  module ProviderResolver
    JEV_PROVIDERS = %i[jev typesafe].freeze
    OPENROUTER_BASE_URL = "https://openrouter.ai/api"
    OPENROUTER_JEV_MODEL = "~typesafe/jev-latest"
    TYPESAFE_JEV_MODEL = "jev-latest"
    OPENROUTER_JEV_MODEL_PATTERN = %r{\A(~?typesafe/)?jev(-|\z)}i
    STRATEGIES = %i[choice score noul bogo].freeze

    Resolution = Struct.new(:provider, :gateway, :api_key, :base_url, :model, keyword_init: true) do
      def jev?
        provider == :jev
      end
    end

    module_function

    # @return [Resolution] +provider+ is :jev or one of Configuration::PROVIDERS
    # @raise [ConfigurationError] for strategy: combined with a generative provider
    def resolve(api_key:, provider: nil, model: nil, strategy: nil, base_url: nil, settings: VibeSort.settings)
      key = clean(api_key)
      explicit = provider&.to_s&.to_sym
      openrouter_key = key&.start_with?("sk-or-") || false
      strategy = validate_strategy!(strategy)
      guard_strategy!(explicit, strategy)

      return jev(key || settings.typesafe_api_key, base_url, model, settings, openrouter: openrouter_key) if JEV_PROVIDERS.include?(explicit)

      return llm(key, explicit) if explicit

      return jev(key, base_url, model, settings, openrouter: true) if openrouter_key && (jev_model_id?(model) || strategy)
      return llm(key, nil) if key && KeyDetector.detect(key)

      if key.nil?
        env_key = settings.typesafe_api_key
        return jev(env_key, base_url, model, settings, openrouter: false) if env_key
      elsif strategy || model.to_s.downcase.start_with?("jev")
        return jev(key, base_url, model, settings, openrouter: false)
      end

      llm(key, nil)
    end

    def jev(key, base_url, model, settings, openrouter:)
      raise ConfigurationError, "API key cannot be nil or empty" if key.nil?

      url = base_url || (openrouter ? OPENROUTER_BASE_URL : settings.typesafe_base_url)
      gateway = url.to_s.include?("openrouter.ai") ? :openrouter : :typesafe
      default_model = settings.jev_model || (gateway == :openrouter ? OPENROUTER_JEV_MODEL : TYPESAFE_JEV_MODEL)
      Resolution.new(provider: :jev, gateway: gateway, api_key: key, base_url: url, model: model || default_model)
    end

    def llm(key, explicit)
      raise ConfigurationError, "API key cannot be nil or empty" if key.nil?

      Resolution.new(provider: explicit || KeyDetector.detect(key) || :openai, api_key: key, model: nil)
    end

    def jev_model_id?(model)
      !model.nil? && OPENROUTER_JEV_MODEL_PATTERN.match?(model.to_s)
    end

    def validate_strategy!(strategy)
      return nil if strategy.nil?

      sym = strategy.to_s.to_sym
      return sym if STRATEGIES.include?(sym)

      raise ConfigurationError, "Unknown strategy: #{strategy.inspect} (supported: #{STRATEGIES.join(", ")})"
    end

    def guard_strategy!(explicit, strategy)
      return unless strategy && explicit && !JEV_PROVIDERS.include?(explicit)

      raise ConfigurationError,
            "strategy: is only supported by System One (:jev) providers, not :#{explicit}"
    end

    def clean(value)
      stripped = value&.to_s&.strip
      stripped.nil? || stripped.empty? ? nil : stripped
    end
  end
end
