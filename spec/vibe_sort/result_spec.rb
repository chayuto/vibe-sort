# frozen_string_literal: true

RSpec.describe VibeSort::Result do
  it "exposes the sort outcome and defaults usage" do
    result = described_class.new(items: [1, 2], strategy: :choice, model: "jev-1.14.0", gateway: :typesafe,
                                 api_calls: 1, warnings: ["careful"])

    expect(result.items).to eq([1, 2])
    expect(result.to_a).to eq([1, 2])
    expect(result.size).to eq(2)
    expect(result.usage).to eq(input_tokens: 0, output_tokens: 0, cost: nil)
    expect(result.item_metadata).to eq([])
    expect(result.to_h).to include(strategy: :choice, model: "jev-1.14.0", gateway: :typesafe, warnings: ["careful"])
  end
end
