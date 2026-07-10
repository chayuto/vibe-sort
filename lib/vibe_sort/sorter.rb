# frozen_string_literal: true

module VibeSort
  # Sorter dispatches the sorting operation to the configured provider adapter
  class Sorter
    PROVIDER_CLASSES = {
      openai: Providers::OpenAI,
      anthropic: Providers::Anthropic,
      gemini: Providers::Gemini,
      groq: Providers::Groq,
      spacexai: Providers::SpaceXAI
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
    # @return [Hash] Result hash with :success, :sorted_array, and optional :error keys
    # @raise [VibeSort::ApiError] if the API request fails
    def perform(array)
      PROVIDER_CLASSES.fetch(config.provider).new(config).perform(array)
    end
  end
end
