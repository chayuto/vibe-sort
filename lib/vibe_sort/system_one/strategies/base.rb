# frozen_string_literal: true

module VibeSort
  module SystemOne
    module Strategies
      # Shared plumbing for the System One sorting strategies.
      #
      # Every strategy works on Entry structs (index + original object) and returns
      # the original objects, so identity is preserved and nothing is ever rebuilt
      # from model text. Only arrays of length 0 or 1 short-circuit; numbers and
      # dates are deliberately NOT sorted with <=> (model jaggedness is a feature).
      class Base
        Entry = Struct.new(:index, :value, :serialized)

        # Mutable per-sort accounting shared by the strategy and its helpers
        attr_reader :warnings, :api_calls, :usage, :resolved_model

        # @param client [SystemOne::Client]
        # @param gateway [Symbol] :typesafe or :openrouter (reported in the Result)
        # @param by [String, nil] sorting criterion
        # @param order [Symbol] :asc or :desc
        # @param options [Hash] strategy options (see subclasses)
        def initialize(client:, gateway: nil, by: nil, order: :asc, **options)
          @client = client
          @gateway = gateway
          @by = by
          @order = validate_order(order)
          @options = options
          @warnings = []
          @api_calls = 0
          @usage = { input_tokens: 0, output_tokens: 0, cost: nil }
          @resolved_model = nil
          @metadata = {}
        end

        # @param array [Array] any objects
        # @return [VibeSort::Result]
        def sort(array)
          entries = array.each_with_index.map { |value, i| Entry.new(i, value, Serializer.call(value)) }
          sorted = entries.size <= 1 ? entries : perform(entries)
          build_result(sorted)
        end

        def self.strategy_name
          name.split("::").last.sub(/Sort\z/, "").downcase.to_sym
        end

        private

        # @param _entries [Array<Entry>] two or more entries
        # @return [Array<Entry>] the entries in sorted order
        def perform(_entries)
          raise NotImplementedError
        end

        def option(key)
          @options.fetch(key)
        end

        def desc?
          @order == :desc
        end

        def goal
          @by || default_goal
        end

        def default_goal
          desc? ? "natural descending order" : "natural ascending order"
        end

        def direction_label
          desc? ? "highest / first to lowest / last" : "lowest / first to highest / last"
        end

        def record(entry, **data)
          @metadata[entry.index] = (@metadata[entry.index] || {}).merge(data)
        end

        # Issue one System One request, accumulating usage and call counts.
        #
        # @return [Hash{String => Hash}] answers keyed by question id
        def ask(state:, questions:)
          response = @client.query(state: state, questions: questions)
          @api_calls += 1
          @resolved_model = response.model
          tally_usage(response.usage)
          response.answers
        end

        def tally_usage(raw)
          @usage[:input_tokens] += raw["input_tokens"].to_i
          @usage[:output_tokens] += raw["output_tokens"].to_i
          cost = raw["cost"]
          @usage[:cost] = (@usage[:cost] || 0.0) + cost.to_f if cost.is_a?(Numeric)
        end

        def answer_for(answers, id, type)
          answer = answers[id]
          raise ApiError, "System One response is missing a #{type.inspect} answer for question #{id.inspect}" unless answer.is_a?(Hash) && answer.key?(type)

          answer
        end

        def build_result(sorted)
          Result.new(
            items: sorted.map(&:value),
            strategy: self.class.strategy_name,
            model: @resolved_model,
            gateway: @gateway,
            api_calls: @api_calls,
            usage: @usage,
            item_metadata: sorted.map { |e| { index: e.index }.merge(@metadata.fetch(e.index, {})) },
            warnings: @warnings
          )
        end

        def validate_order(order)
          sym = order.to_s.to_sym
          return sym if %i[asc desc].include?(sym)

          raise ConfigurationError, "order: must be :asc or :desc, got #{order.inspect}"
        end
      end
    end
  end
end
