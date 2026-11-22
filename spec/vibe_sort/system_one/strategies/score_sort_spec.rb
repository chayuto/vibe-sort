# frozen_string_literal: true

RSpec.describe VibeSort::SystemOne::Strategies::ScoreSort do
  let(:scores) { { "a" => 3.9, "b" => 0.1, "c" => 2.0 } }

  def scoring_client(scores, confidence: 0.9, pairs: nil)
    FakeSystemOne.new do |state, questions|
      questions.to_h do |id, _question|
        if id.start_with?("s_")
          item = state["items"]["i_#{id.delete_prefix("s_")}"]
          [id, score_answer(scores.fetch(item), confidence: confidence)]
        else
          [id, pairs.fetch(id)]
        end
      end
    end
  end

  def sorter(fake, **options)
    described_class.new(client: fake, gateway: :openrouter, tie_break: false, **options)
  end

  it "rates everything in a single request and sorts by score" do
    fake = scoring_client(scores)

    result = sorter(fake).sort(%w[a b c])

    expect(result.items).to eq(%w[b c a])
    expect(fake.calls.size).to eq(1)
    expect(fake.calls.first[:questions].keys).to eq(%w[s_0 s_1 s_2])
    expect(result.item_metadata.first).to include(index: 1, score: 0.1, confidence: 0.9)
  end

  it "sends the 5-level relative rubric by default" do
    fake = scoring_client(scores)

    sorter(fake, by: "spiciest pepper").sort(%w[a b c])

    criteria = fake.calls.first[:questions]["s_0"]["criteria"]
    expect(criteria.size).to eq(5)
    expect(criteria.first).to eq("At the absolute bottom / very start of this array for: spiciest pepper")
  end

  it "reverses the Ruby sort for order: :desc (stable on ties)" do
    fake = scoring_client({ "a" => 1.0, "b" => 1.0, "c" => 2.0 })

    result = sorter(fake, order: :desc).sort(%w[a b c])

    expect(result.items).to eq(%w[c a b])
  end

  it "keeps the rubric ascending-relative when order is :desc" do
    fake = scoring_client(scores)

    sorter(fake, order: :desc).sort(%w[a b c])

    expect(fake.calls.first[:state]["sorting_goal"]).to eq("natural ascending order")
  end

  it "validates custom rubrics" do
    fake = scoring_client(scores)

    expect { sorter(fake, rubric: ["only one"]) }.to raise_error(ArgumentError, /rubric/)
    expect { sorter(fake, rubric: Array.new(11) { |i| "level #{i}" }) }.to raise_error(ArgumentError, /rubric/)
    expect { sorter(fake, rubric: ["ok", ""]) }.to raise_error(ArgumentError, /rubric/)
    expect { sorter(fake, rubric: %w[low high]) }.not_to raise_error
  end

  it "passes a custom rubric through" do
    fake = scoring_client(scores)

    sorter(fake, rubric: %w[meh wow]).sort(%w[a b c])

    expect(fake.calls.first[:questions]["s_0"]["criteria"]).to eq(%w[meh wow])
  end

  it "warns about low-confidence (bimodal) scores" do
    fake = scoring_client(scores, confidence: 0.3)

    result = sorter(fake).sort(%w[a b c])

    expect(result.warnings.size).to eq(3)
    expect(result.warnings.first).to match(/Low confidence \(0\.3\) scoring item 0/)
  end

  it "returns original references and skips the call for 0/1 items" do
    fake = FakeSystemOne.new { raise "no calls expected" }
    only = +"solo"

    expect(sorter(fake).sort([]).items).to eq([])
    expect(sorter(fake).sort([only]).items.first).to equal(only)
  end

  describe "adjacent tie-break" do
    let(:close) { { "a" => 2.0, "b" => 2.05, "c" => 4.0 } }

    def tie_sorter(fake, **options)
      described_class.new(client: fake, tie_break: true, **options)
    end

    it "sends one batched choice request for near-ties and swaps when 'right' wins" do
      fake = scoring_client(close, pairs: { "pair_0" => choice_answer("right", confidence: 0.8) })

      result = tie_sorter(fake).sort(%w[a b c])

      expect(result.items).to eq(%w[b a c])
      expect(fake.calls.size).to eq(2)
      pair_call = fake.calls.last
      expect(pair_call[:questions].keys).to eq(["pair_0"])
      expect(pair_call[:questions]["pair_0"]["criteria"]).to eq("left" => "a", "right" => "b")
    end

    it "ignores low-confidence tie-break answers and 'left' answers" do
      fake = scoring_client(close, pairs: { "pair_0" => choice_answer("right", confidence: 0.2) })
      expect(tie_sorter(fake).sort(%w[a b c]).items).to eq(%w[a b c])

      fake = scoring_client(close, pairs: { "pair_0" => choice_answer("left") })
      expect(tie_sorter(fake).sort(%w[a b c]).items).to eq(%w[a b c])
    end

    it "makes no second call when nothing is ambiguous" do
      fake = scoring_client({ "a" => 0.0, "b" => 2.0, "c" => 4.0 })

      tie_sorter(fake).sort(%w[a b c])

      expect(fake.calls.size).to eq(1)
    end

    it "applies only non-overlapping swaps" do
      fake = scoring_client({ "a" => 1.0, "b" => 1.01, "c" => 1.02 },
                            pairs: { "pair_0" => choice_answer("right"), "pair_1" => choice_answer("right") })

      result = tie_sorter(fake).sort(%w[a b c])

      expect(result.items).to eq(%w[b a c])
    end
  end
end
