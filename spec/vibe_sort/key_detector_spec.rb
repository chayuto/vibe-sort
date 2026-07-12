# frozen_string_literal: true

RSpec.describe VibeSort::KeyDetector do
  {
    "sk-ant-api03-abc123" => :anthropic,
    "sk-or-v1-abc123" => :openrouter,
    "sk-proj-abc123" => :openai,
    "sk-abc123" => :openai,
    "gsk_abc123" => :groq,
    "AIzaSyAbc123" => :gemini,
    "AQ.Ab8Rabc123" => :gemini,
    "xai-abc123" => :spacexai
  }.each do |key, provider|
    it "detects #{key.split("-").first[0, 6]}... keys as :#{provider}" do
      expect(described_class.detect(key)).to eq(provider)
    end
  end

  it "returns nil for unrecognized key formats" do
    expect(described_class.detect("some-proxy-token")).to be_nil
  end

  it "orders specific prefixes before the generic sk- prefix" do
    prefixes = described_class::PREFIXES.keys
    expect(prefixes.index("sk-ant-")).to be < prefixes.index("sk-")
    expect(prefixes.index("sk-or-")).to be < prefixes.index("sk-")
  end
end
