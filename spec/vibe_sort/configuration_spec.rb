# frozen_string_literal: true

RSpec.describe VibeSort::Configuration do
  it "defaults to the openai provider with no model override" do
    config = described_class.new(api_key: "test-key")

    expect(config.provider).to eq(:openai)
    expect(config.model).to be_nil
    expect(config.temperature).to eq(0.0)
    expect(config.extra_params).to eq({})
  end

  it "infers the provider from the api_key prefix when provider is omitted" do
    config = described_class.new(api_key: "sk-ant-api03-abc123")

    expect(config.provider).to eq(:anthropic)
  end

  it "keeps the explicit provider without warning when it matches the key prefix" do
    expect do
      config = described_class.new(api_key: "gsk_abc123", provider: :groq)
      expect(config.provider).to eq(:groq)
    end.not_to output.to_stderr
  end

  it "keeps the explicit provider but warns when the key prefix suggests another" do
    config = nil
    expect do
      config = described_class.new(api_key: "sk-ant-api03-abc123", provider: :openai)
    end.to output(/api_key format suggests :anthropic but provider is :openai/).to_stderr

    expect(config.provider).to eq(:openai)
  end

  it "does not warn for an explicit provider with an unrecognized key format" do
    expect do
      described_class.new(api_key: "some-proxy-token", provider: :groq)
    end.not_to output.to_stderr
  end

  it "stores extra_params" do
    config = described_class.new(api_key: "test-key", extra_params: { max_tokens: 100 })

    expect(config.extra_params).to eq(max_tokens: 100)
  end

  it "accepts the provider as a string" do
    config = described_class.new(api_key: "test-key", provider: "anthropic")

    expect(config.provider).to eq(:anthropic)
  end

  it "accepts a model override" do
    config = described_class.new(api_key: "test-key", provider: :gemini, model: "gemini-2.5-pro")

    expect(config.model).to eq("gemini-2.5-pro")
  end

  it "raises ArgumentError for an unknown provider" do
    expect do
      described_class.new(api_key: "test-key", provider: :grok)
    end.to raise_error(ArgumentError, /Unknown provider: :grok/)
  end

  it "raises ArgumentError for a nil API key" do
    expect do
      described_class.new(api_key: nil)
    end.to raise_error(ArgumentError, "API key cannot be nil or empty")
  end

  it "raises ArgumentError for an empty API key" do
    expect do
      described_class.new(api_key: "")
    end.to raise_error(ArgumentError, "API key cannot be nil or empty")
  end
end
