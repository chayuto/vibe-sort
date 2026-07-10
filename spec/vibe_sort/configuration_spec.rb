# frozen_string_literal: true

RSpec.describe VibeSort::Configuration do
  it "defaults to the openai provider with no model override" do
    config = described_class.new(api_key: "test-key")

    expect(config.provider).to eq(:openai)
    expect(config.model).to be_nil
    expect(config.temperature).to eq(0.0)
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
