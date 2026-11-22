# frozen_string_literal: true

RSpec.describe VibeSort::SystemOne::Strategies::NoulSort do
  # Answers "should item_a come before item_b" from a block over the two items
  def comparator(&before)
    FakeSystemOne.new do |state, _questions|
      { "a_before_b" => noul_answer(before.call(state["item_a"], state["item_b"])) }
    end
  end

  def sorter(fake, **options)
    described_class.new(client: fake, **options)
  end

  it "merge-sorts with pairwise questions" do
    fake = comparator { |a, b| a < b ? 0.95 : 0.05 }

    result = sorter(fake).sort(%w[d b a c])

    expect(result.items).to eq(%w[a b c d])
    expect(fake.calls.size).to be <= 8 # ceil(4 * log2 4)
    question = fake.calls.first[:questions]["a_before_b"]
    expect(question["type"]).to eq("noul")
    expect(question["criteria"].keys).to eq(%w[true false])
    expect(fake.calls.first[:state].keys).to eq(%w[sorting_goal direction item_a item_b])
  end

  it "never asks about the same pair twice, in either direction" do
    fake = comparator { |a, b| a < b ? 0.9 : 0.1 }

    sorter(fake).sort(%w[e d c b a])

    pairs = fake.calls.map { |c| [c[:state]["item_a"], c[:state]["item_b"]] }
    expect(pairs.map(&:sort)).to eq(pairs.map(&:sort).uniq)
  end

  it "reuses cached answers for duplicate values at different indices only per index pair" do
    fake = comparator { |a, b| a <= b ? 0.9 : 0.1 }

    result = sorter(fake).sort(%w[b a b a])

    expect(result.items).to eq(%w[a a b b])
  end

  it "terminates on non-transitive judgments (A < B < C < A)" do
    beats = { %w[A B] => 0.9, %w[B C] => 0.9, %w[C A] => 0.9 }
    fake = comparator { |a, b| beats[[a, b]] || (1 - (beats[[b, a]] || 0.5)) }

    result = sorter(fake).sort(%w[A B C])

    expect(result.items).to match_array(%w[A B C])
    expect(result.api_calls).to be <= 3
  end

  it "treats the uncertain band as a tie and keeps input order (stable)" do
    fake = comparator { |_a, _b| 0.5 }

    result = sorter(fake).sort(%w[x y z w])

    expect(result.items).to eq(%w[x y z w])
  end

  it "flips the decision for answers below the band" do
    fake = comparator { |_a, _b| 0.3 }

    expect(sorter(fake).sort(%w[x y]).items).to eq(%w[y x])
  end

  it "applies the direction label and returns original references" do
    items = [+"b", +"a"]
    fake = comparator { |a, b| a < b ? 0.9 : 0.1 }

    result = sorter(fake, order: :desc, by: "alphabet").sort(items)

    expect(fake.calls.first[:state]["direction"]).to start_with("highest / first")
    expect(fake.calls.first[:state]["sorting_goal"]).to eq("alphabet")
    expect(result.items.first).to equal(items.first).or equal(items.last)
    expect(result.item_metadata.first[:comparisons]).to eq(1)
  end

  it "makes no calls for empty and single arrays" do
    fake = FakeSystemOne.new { raise "no calls" }

    expect(sorter(fake).sort([]).api_calls).to eq(0)
    expect(sorter(fake).sort([1]).items).to eq([1])
  end
end
