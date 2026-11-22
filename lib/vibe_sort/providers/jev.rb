# frozen_string_literal: true

module VibeSort
  module Providers
    # Adapter for TypeSafe's Jev (System One) decision model. Unlike the generative
    # providers it never writes an array: it answers typed questions about item
    # indices, and the sorted result is assembled from the original objects.
    class Jev
      STRATEGIES = {
        choice: SystemOne::Strategies::ChoiceSort,
        score: SystemOne::Strategies::ScoreSort,
        noul: SystemOne::Strategies::NoulSort,
        bogo: SystemOne::Strategies::BogoSort
      }.freeze

      # Per-sort options accepted by #sort_with_metadata / #perform
      SORT_OPTIONS = %i[by prompt order strategy rubric tie_break tie_epsilon confidence_floor max_attempts threshold
                        strict long_context shuffle_options rng].freeze
      # Options that may also be set once on Client.new
      CLIENT_OPTIONS = (SORT_OPTIONS + %i[max_retries timeout openrouter_referer openrouter_title sleeper]).freeze

      attr_reader :config

      # @param config [VibeSort::Configuration] resolved Jev configuration
      def initialize(config)
        @config = config
      end

      # Drop-in counterpart of the generative providers' #perform
      #
      # @return [Hash] { success: true, sorted_array: [...] }
      def perform(array, **overrides)
        { success: true, sorted_array: sort_with_metadata(array, **overrides).items }
      end

      # @return [VibeSort::Result]
      def sort_with_metadata(array, **overrides)
        opts = effective_options(overrides)
        strategy = opts[:strategy].to_sym
        klass = STRATEGIES.fetch(strategy) do
          raise ConfigurationError, "Unknown strategy: #{strategy.inspect} (supported: #{STRATEGIES.keys.join(", ")})"
        end

        klass.new(client: build_client(opts), gateway: config.gateway, by: opts[:by] || opts[:prompt],
                  order: opts[:order] || :asc, **strategy_options(opts)).sort(array)
      end

      private

      def effective_options(overrides)
        unknown = overrides.keys - SORT_OPTIONS
        raise ConfigurationError, "Unknown sort option(s): #{unknown.join(", ")}" unless unknown.empty?

        VibeSort.settings.to_options.merge(config.jev_options).merge(overrides.compact)
      end

      def strategy_options(opts)
        opts.slice(:rubric, :tie_break, :tie_epsilon, :confidence_floor, :max_attempts, :threshold,
                   :strict, :shuffle_options, :rng)
      end

      def build_client(opts)
        SystemOne::Client.new(
          api_key: config.api_key, base_url: config.base_url, model: config.model,
          long_context: opts[:long_context], max_retries: opts[:max_retries], timeout: opts[:timeout],
          referer: opts[:openrouter_referer], title: opts[:openrouter_title],
          **opts.slice(:sleeper)
        )
      end
    end
  end
end
