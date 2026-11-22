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
    # @param provider [Symbol, String, nil] LLM provider: :openai, :anthropic, :gemini,
    #   :groq, :spacexai, or :openrouter. When omitted, the provider is inferred from
    #   the api_key prefix (e.g. "sk-ant-..." routes to Anthropic), falling back to
    #   :openai for unrecognized key formats.
    # @param model [String, nil] Model ID override (nil uses the provider's default)
    # @param extra_params [Hash] Provider-native request parameters deep-merged into
    #   the request payload last, so they can override anything the adapter builds
    # @raise [ArgumentError] if api_key or provider is invalid
    #
    # @example Provider inferred from the key prefix
    #   client = VibeSort::Client.new(api_key: ENV['ANTHROPIC_API_KEY']) # sk-ant-... => :anthropic
    #
    # @example OpenAI (explicit)
    #   client = VibeSort::Client.new(provider: :openai, api_key: ENV['OPENAI_API_KEY'])
    #
    # @example Google Gemini with a custom model
    #   client = VibeSort::Client.new(provider: :gemini, api_key: ENV['GEMINI_API_KEY'], model: 'gemini-2.5-pro')
    #
    # @example OpenRouter with extra request parameters
    #   client = VibeSort::Client.new(
    #     provider: :openrouter,
    #     api_key: ENV['OPENROUTER_API_KEY'],
    #     model: 'meta-llama/llama-3.3-70b-instruct',
    #     extra_params: { max_tokens: 200 }
    #   )
    #
    # @example TypeSafe Jev (System One) with the pairwise merge-sort strategy
    #   client = VibeSort::Client.new(api_key: ENV['TYPESAFE_API_KEY'], provider: :jev, strategy: :noul)
    #
    # @example Jev through OpenRouter (an sk-or- key plus a jev model or a strategy: routes there)
    #   client = VibeSort::Client.new(api_key: ENV['OPENROUTER_API_KEY'], model: 'jev-latest')
    #
    # System One accepts extra keywords (+strategy:+, +by:+, +order:+, +long_context:+, ...), all
    # of which can also be passed per call to #sort / #sort_with_metadata. +api_key+ may be omitted
    # when TYPESAFE_API_KEY is set. See VibeSort::Providers::Jev for the full list.
    #
    # @param base_url [String, nil] System One gateway root override (Jev only)
    def initialize(api_key: nil, temperature: 0.0, provider: nil, model: nil, extra_params: {}, base_url: nil, **jev_options)
      validate_jev_options!(jev_options)
      @config = Configuration.new(api_key: api_key, temperature: temperature, provider: provider, model: model,
                                  extra_params: extra_params, base_url: base_url, jev_options: jev_options)
      reject_jev_options_for_llm!(jev_options)
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
    #   # The error prefix names the configured provider (OpenAI, Anthropic, Gemini, ...)
    #
    # With a System One (Jev) provider the array may hold any objects (the originals are
    # returned, never rebuilt from model text), an empty array is valid, and per-call
    # options such as +strategy:+, +by:+ and +order:+ are accepted.
    #
    # @example Jev, descending, by a custom criterion
    #   client.sort(%w[ghost-pepper jalapeno habanero], by: "spiciness", order: :desc)
    #   #=> { success: true, sorted_array: ["ghost-pepper", "habanero", "jalapeno"] }
    def sort(array, **options)
      unless valid_input?(array)
        return {
          success: false,
          sorted_array: [],
          error: config.jev? ? "Input must be an array" : "Input must be an array of numbers or strings"
        }
      end

      # Perform the sort via API
      sorter = Sorter.new(config)
      sorter.perform(array, **options)
    rescue ApiError, ConfigurationError, BogoExhaustedError => e
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

    # Sort with a System One (Jev) provider and get the full picture back.
    #
    # Unlike #sort this raises on failure (VibeSort::ApiError subclasses,
    # ConfigurationError, BogoExhaustedError) and returns a VibeSort::Result carrying the
    # sorted items, resolved model, API call count, token usage, per-item scores /
    # confidences / probabilities, and warnings.
    #
    # @param array [Array] any objects
    # @param options [Hash] per-call System One options (+strategy:+, +by:+, +order:+, +rubric:+, ...)
    # @return [VibeSort::Result]
    #
    # @example
    #   result = client.sort_with_metadata(%w[pizza kale cake], by: "tastiness", strategy: :score)
    #   result.items         #=> ["kale", "pizza", "cake"]
    #   result.item_metadata #=> [{ index: 1, score: 1.2, confidence: 0.8, ... }, ...]
    def sort_with_metadata(array, **options)
      raise ArgumentError, "Input must be an array" unless array.is_a?(Array)

      Sorter.new(config).perform_with_metadata(array, **options)
    end

    private

    def validate_jev_options!(jev_options)
      unknown = jev_options.keys - Providers::Jev::CLIENT_OPTIONS
      return if unknown.empty?

      raise ConfigurationError, "Unknown option(s): #{unknown.join(", ")}"
    end

    def reject_jev_options_for_llm!(jev_options)
      return if config.jev? || jev_options.empty?

      raise ConfigurationError, "#{jev_options.keys.join(", ")}: only supported by System One (:jev) providers, not :#{config.provider}"
    end

    # Validate the input array: Jev accepts any array; generative providers need a
    # non-empty array of numbers and/or strings
    #
    # @param array [Object] Input to validate
    # @return [Boolean] true if valid, false otherwise
    def valid_input?(array)
      return false unless array.is_a?(Array)
      return true if config.jev?
      return false if array.empty?

      array.all? { |item| item.is_a?(Numeric) || item.is_a?(String) }
    end
  end
end
