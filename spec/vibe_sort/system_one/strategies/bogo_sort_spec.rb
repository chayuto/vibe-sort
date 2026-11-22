# frozen_string_literal: true

RSpec.describe VibeSort::SystemOne::Strategies::BogoSort do
  let(:items) { %w[a b c d] }

  def judge(probabilities)
    queue = probabilities.dup
    FakeSystemOne.new { |_state, _questions| { "is_sorted" => noul_answer(queue.shift || queue.last || 0.0) } }
  end

  def sorter(fake, **options)
    described_class.new(client: fake, rng: Random.new(7), **options)
  end

  it "stops as soon as an attempt clears the threshold" do
    fake = judge([0.1, 0.2, 0.95, 0.99])

    result = sorter(fake).sort(items)

    expect(fake.calls.size).to eq(3)
    expect(result.api_calls).to eq(3)
    expect(result.warnings).to be_empty
    expect(result.items).to eq(fake.calls.last[:state]["array"])
    expect(result.item_metadata.first).to include(sortedness_probability: 0.95, attempts: 3)
  end

  it "asks one noul 'is_sorted' question over the candidate array" do
    fake = judge([1.0])

    sorter(fake, by: "size", order: :desc).sort(items)

    state = fake.calls.first[:state]
    expect(state["array"]).to match_array(items)
    expect([state["sorting_goal"], state["direction"]]).to eq(["size", "highest / first to lowest / last"])
    expect(fake.calls.first[:questions]["is_sorted"]["type"]).to eq("noul")
  end

  it "returns the most convincing shuffle with a warning when the cap is hit" do
    fake = judge([0.2, 0.8, 0.4])

    result = sorter(fake, max_attempts: 3).sort(items)

    expect(fake.calls.size).to eq(3)
    expect(result.items).to eq(fake.calls[1][:state]["array"])
    expect(result.warnings.first).to match(/3-attempt cap.*0\.8/)
  end

  it "raises BogoExhaustedError in strict mode" do
    fake = judge([0.2, 0.6])

    expect { sorter(fake, max_attempts: 2, strict: true).sort(items) }
      .to raise_error(VibeSort::BogoExhaustedError) { |e|
        expect(e.attempts).to eq(2)
        expect(e.best_probability).to eq(0.6)
      }
  end

  it "validates max_attempts and threshold" do
    fake = judge([1.0])

    expect { sorter(fake, max_attempts: 0) }.to raise_error(ArgumentError, /max_attempts/)
    expect { sorter(fake, max_attempts: 2.5) }.to raise_error(ArgumentError, /max_attempts/)
    expect { sorter(fake, threshold: 1.5) }.to raise_error(ArgumentError, /threshold/)
    expect { sorter(fake, max_attempts: Float::INFINITY) }.not_to raise_error
  end

  it "short-circuits arrays of length 0 or 1 and preserves identity" do
    fake = FakeSystemOne.new { raise "no calls" }
    one = Object.new

    expect(sorter(fake).sort([]).items).to eq([])
    expect(sorter(fake).sort([one]).items.first).to equal(one)
  end
end
