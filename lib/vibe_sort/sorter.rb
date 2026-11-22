# frozen_string_literal: true

module VibeSort
  # Sorter dispatches the sorting operation to the configured provider adapter
  class Sorter
    PROVIDER_CLASSES = {
      openai: Providers::OpenAI,
      anthropic: Providers::Anthropic,
      gemini: Providers::Gemini,
      groq: Providers::Groq,
      spacexai: Providers::SpaceXAI,
      openrouter: Providers::OpenRouter,
      jev: Providers::Jev
    }.freeze

    attr_reader :config

    # Initialize a new Sorter
    #
    # @param config [VibeSort::Configuration] Configuration object
    def initialize(config)
      @config = config
    end

    # Perform the sorting operation via the configured provider's API
    #
    # @param array [Array] Array of numbers and/or strings to sort
    # @param options [Hash] System One (Jev) per-sort options; not accepted by generative providers
    # @return [Hash] Result hash with :success, :sorted_array, and optional :error keys
    # @raise [VibeSort::ApiError] if the API request fails
    def perform(array, **options)
      provider = PROVIDER_CLASSES.fetch(config.provider).new(config)
      raise ConfigurationError, "#{options.keys.join(", ")}: only supported by System One (:jev) providers, not :#{config.provider}" unless options.empty? || config.jev?

      options.empty? ? provider.perform(array) : provider.perform(array, **options)
    end

    # @return [VibeSort::Result] System One providers only
    def perform_with_metadata(array, **options)
      raise ConfigurationError, "sort_with_metadata requires a System One (:jev) provider, not :#{config.provider}" unless config.jev?

      PROVIDER_CLASSES.fetch(:jev).new(config).sort_with_metadata(array, **options)
    end
  end
end
