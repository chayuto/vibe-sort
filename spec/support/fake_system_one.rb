# frozen_string_literal: true

# Stands in for VibeSort::SystemOne::Client in strategy specs: records each call
# and answers via a block, so strategies run with zero HTTP.
class FakeSystemOne
  attr_reader :calls

  def initialize(model: "jev-1.14.0", usage: { "input_tokens" => 10, "output_tokens" => 1 }, &responder)
    @responder = responder
    @model = model
    @usage = usage
    @calls = []
  end

  def query(state:, questions:)
    # Record exactly what would go over the wire (string keys, sanitised values)
    wire_state = VibeSort::SystemOne::Serializer.call(state)
    wire_questions = VibeSort::SystemOne::Serializer.call(questions)
    @calls << { state: wire_state, questions: wire_questions }
    answers = @responder.call(wire_state, wire_questions)
    VibeSort::SystemOne::Client::Response.new(model: @model, answers: answers, usage: @usage.dup)
  end
end

module SystemOneHelpers
  def choice_answer(key, confidence: 0.9)
    { "type" => "choice", "choice" => key, "confidence" => confidence, "probabilities" => { key => confidence } }
  end

  def noul_answer(probability)
    { "type" => "noul", "noul" => probability }
  end

  def score_answer(score, confidence: 0.9)
    { "type" => "score", "score" => score, "confidence" => confidence, "probabilities" => {} }
  end

  # JSON body of a successful /v1/systemone response
  def systemone_body(answers, model: "jev-1.14.0", usage: { "input_tokens" => 5, "output_tokens" => 1 }, **extra)
    JSON.generate({ "model" => model, "answers" => answers, "usage" => usage }.merge(extra.transform_keys(&:to_s)))
  end
end

RSpec.configure { |config| config.include SystemOneHelpers }
