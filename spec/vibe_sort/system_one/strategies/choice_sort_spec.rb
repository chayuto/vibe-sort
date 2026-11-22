# frozen_string_literal: true

RSpec.describe VibeSort::SystemOne::Strategies::ChoiceSort do
  let(:rng) { Random.new(1) }

  # A "model" that picks the candidate with the smallest (or largest) rank
  def ranked_responder(rank, direction: :min)
    lambda do |state, questions|
      questions.to_h do |id, question|
        keys = question["criteria"].keys
        values = state["candidates"] || question["criteria"]
        pick = keys.public_send(direction == :min ? :min_by : :max_by) { |k| rank.call(values[k]) }
        [id, choice_answer(pick)]
      end
    end
  end

  def sorter(fake, **options)
    described_class.new(client: fake, gateway: :typesafe, rng: rng, **options)
  end

  it "makes no calls for empty and single-element arrays" do
    fake = FakeSystemOne.new { raise "should not be called" }

    expect(sorter(fake).sort([]).items).to eq([])
    single = Object.new
    expect(sorter(fake).sort([single]).items.first).to equal(single)
    expect(fake.calls).to be_empty
  end

  it "sorts 4 items in 3 calls with null criteria and items held in state" do
    fake = FakeSystemOne.new(&ranked_responder(:itself.to_proc))

    result = sorter(fake).sort(%w[pear apple fig cherry])

    expect(result.items).to eq(%w[apple cherry fig pear])
    expect(fake.calls.size).to eq(3)
    expect(result.api_calls).to eq(3)
    fake.calls.each do |call|
      criteria = call[:questions]["pick_next"]["criteria"]
      expect(criteria.values).to all(be_nil)
      expect(call[:state]["candidates"].keys).to match_array(criteria.keys)
    end
  end

  it "reports model, gateway, accumulated usage and per-item pick metadata" do
    fake = FakeSystemOne.new(&ranked_responder(:itself.to_proc))

    result = sorter(fake).sort(%w[b c a])

    expect(result.strategy).to eq(:choice)
    expect(result.model).to eq("jev-1.14.0")
    expect(result.gateway).to eq(:typesafe)
    expect(result.usage).to eq(input_tokens: 20, output_tokens: 2, cost: nil)
    expect(result.item_metadata.map { |m| m[:index] }).to eq([2, 0, 1])
    expect(result.item_metadata.first).to include(pick_round: 1, confidence: 0.9)
    expect(result.item_metadata.last).to eq(index: 1)
  end

  it "supports order: :desc and says so in the question" do
    fake = FakeSystemOne.new(&ranked_responder(:itself.to_proc, direction: :max))

    result = sorter(fake, order: :desc).sort(%w[b c a])

    expect(result.items).to eq(%w[c b a])
    expect(fake.calls.first[:state]["direction"]).to start_with("highest / first")
  end

  it "uses the by: criterion as the sorting goal" do
    fake = FakeSystemOne.new(&ranked_responder(:itself.to_proc))

    sorter(fake, by: "spiciness").sort(%w[b a])

    expect(fake.calls.first[:state]["sorting_goal"]).to eq("spiciness")
  end

  it "returns the original object references, including mutable and custom objects" do
    point = Struct.new(:name, :rank)
    items = [point.new("c", 3), { "name" => "a", "rank" => 1 }, point.new("b", 2)]
    fake = FakeSystemOne.new(&ranked_responder(->(v) { v["rank"] }))

    result = sorter(fake).sort(items)

    expect(result.items.size).to eq(3)
    expect(result.items[0]).to equal(items[1])
    expect(result.items[1]).to equal(items[2])
    expect(result.items[2]).to equal(items[0])
  end

  it "shuffles option order unless disabled" do
    fake = FakeSystemOne.new(&ranked_responder(:itself.to_proc))
    sorter(fake).sort(("a".."h").to_a)
    keys = fake.calls.first[:questions]["pick_next"]["criteria"].keys

    expect(keys).not_to eq(keys.sort_by { |k| k[2..].to_i })

    fake = FakeSystemOne.new(&ranked_responder(:itself.to_proc))
    sorter(fake, shuffle_options: false).sort(("a".."h").to_a)
    keys = fake.calls.first[:questions]["pick_next"]["criteria"].keys
    expect(keys).to eq(keys.sort_by { |k| k[2..].to_i })
  end

  it "falls back to the most probable valid key when Jev names an unknown one" do
    fake = FakeSystemOne.new do |_state, _questions|
      { "pick_next" => { "type" => "choice", "choice" => "i_99", "confidence" => 0.2,
                         "probabilities" => { "i_99" => 0.5, "i_1" => 0.3, "i_0" => 0.2 } } }
    end

    result = sorter(fake, shuffle_options: false).sort(%w[x y])

    expect(result.items).to eq(%w[y x])
    expect(result.warnings.first).to match(/unknown candidate/)
  end

  it "raises ApiError when the answer is missing entirely" do
    fake = FakeSystemOne.new { |_s, _q| {} }

    expect { sorter(fake).sort(%w[a b]) }.to raise_error(VibeSort::ApiError, /missing a choice answer/)
  end

  context "with more than 255 items" do
    let(:items) { (1..260).map { |n| format("item-%03d", n) } }

    it "uses tournament chunking and never asks more than 255 options per question" do
      fake = FakeSystemOne.new(&ranked_responder(:itself.to_proc))

      result = sorter(fake, shuffle_options: false).sort(items)

      expect(result.items).to eq(items)
      sizes = fake.calls.flat_map { |c| c[:questions].values.map { |q| q["criteria"].size } }
      expect(sizes.max).to be <= 255
      expect(fake.calls.first[:questions].keys).to eq(%w[chunk_0 chunk_1])
      # state never carries the full candidate list in tournament rounds
      expect(fake.calls.first[:state]).not_to have_key("candidates")
    end
  end
end
