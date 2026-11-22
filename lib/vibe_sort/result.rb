# frozen_string_literal: true

module VibeSort
  # Value object returned by Client#sort_with_metadata for System One (Jev) providers.
  #
  # +items+ holds the original Ruby objects (same identities as the input), never
  # values reconstructed from model output.
  class Result
    attr_reader :items, :strategy, :model, :gateway, :api_calls, :usage, :item_metadata, :warnings

    def initialize(items:, strategy:, model: nil, gateway: nil, api_calls: 0, usage: nil, item_metadata: [], warnings: [])
      @items = items
      @strategy = strategy
      @model = model
      @gateway = gateway
      @api_calls = api_calls
      @usage = usage || { input_tokens: 0, output_tokens: 0, cost: nil }
      @item_metadata = item_metadata
      @warnings = warnings
    end

    def to_a
      items
    end

    def size
      items.size
    end

    def to_h
      {
        items: items, strategy: strategy, model: model, gateway: gateway, api_calls: api_calls,
        usage: usage, item_metadata: item_metadata, warnings: warnings
      }
    end
  end
end
