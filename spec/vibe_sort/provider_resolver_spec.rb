# frozen_string_literal: true

RSpec.describe VibeSort::ProviderResolver do
  def resolve(**kwargs)
    described_class.resolve(**kwargs)
  end

  describe "tier 1: provider: :jev with an OpenRouter key" do
    it "routes to Jev via OpenRouter with the ~typesafe default model" do
      r = resolve(api_key: "sk-or-v1-abc", provider: :jev)

      expect(r.provider).to eq(:jev)
      expect(r.gateway).to eq(:openrouter)
      expect(r.base_url).to eq("https://openrouter.ai/api")
      expect(r.model).to eq("~typesafe/jev-latest")
    end

    it "treats :typesafe as an alias for :jev" do
      expect(resolve(api_key: "sk-or-v1-abc", provider: :typesafe).provider).to eq(:jev)
    end
  end

  describe "tier 2: provider: :jev with another key" do
    it "routes to TypeSafe Direct with jev-latest" do
      r = resolve(api_key: "ts-key", provider: :jev)

      expect([r.gateway, r.base_url, r.model]).to eq([:typesafe, "https://api.typesafe.ai", "jev-latest"])
    end

    it "falls back to TYPESAFE_API_KEY, stripping whitespace" do
      ENV["TYPESAFE_API_KEY"] = "  ts-env-key \n"

      expect(resolve(api_key: nil, provider: :jev).api_key).to eq("ts-env-key")
    end

    it "honours TYPESAFE_BASE_URL and an explicit base_url (which wins)" do
      ENV["TYPESAFE_BASE_URL"] = "https://typesafe.example"
      expect(resolve(api_key: "ts", provider: :jev).base_url).to eq("https://typesafe.example")
      expect(resolve(api_key: "ts", provider: :jev, base_url: "https://other.test").base_url).to eq("https://other.test")
    end

    it "raises when no key can be found" do
      expect { resolve(api_key: nil, provider: :jev) }.to raise_error(ArgumentError, "API key cannot be nil or empty")
    end
  end

  describe "tier 3: OpenRouter key with a jev model" do
    %w[jev-latest jev-1.14.0 typesafe/jev-latest ~typesafe/jev-latest].each do |model|
      it "routes #{model} to Jev and passes the model through" do
        r = resolve(api_key: "sk-or-v1-abc", model: model)

        expect([r.provider, r.gateway, r.model]).to eq([:jev, :openrouter, model])
      end
    end

    it "does not capture other models" do
      expect(resolve(api_key: "sk-or-v1-abc", model: "openai/gpt-4o").provider).to eq(:openrouter)
      expect(resolve(api_key: "sk-or-v1-abc", model: "jevons/model").provider).to eq(:openrouter)
    end
  end

  describe "tier 4: OpenRouter key with strategy:" do
    it "routes to Jev via OpenRouter" do
      r = resolve(api_key: "sk-or-v1-abc", strategy: :choice)

      expect([r.provider, r.gateway, r.model]).to eq([:jev, :openrouter, "~typesafe/jev-latest"])
    end
  end

  describe "tier 5: existing key-prefix rules" do
    {
      "sk-or-v1-abc" => :openrouter, "sk-ant-api03-x" => :anthropic, "sk-proj-x" => :openai,
      "gsk_x" => :groq, "xai-x" => :spacexai, "AIzaX" => :gemini
    }.each do |key, provider|
      it "keeps #{key[0, 6]}... on #{provider}" do
        r = resolve(api_key: key)

        expect(r.provider).to eq(provider)
        expect(r).not_to be_jev
      end
    end

    it "keeps an explicit generative provider" do
      expect(resolve(api_key: "anything", provider: :groq).provider).to eq(:groq)
    end

    it "defaults unrecognised keys to :openai like 0.4.0" do
      expect(resolve(api_key: "some-proxy-token").provider).to eq(:openai)
    end
  end

  describe "tier 6: no key, TYPESAFE_API_KEY set" do
    it "routes to TypeSafe Direct" do
      ENV["TYPESAFE_API_KEY"] = "ts-env"

      r = resolve(api_key: nil)

      expect([r.provider, r.gateway, r.api_key]).to eq([:jev, :typesafe, "ts-env"])
    end

    it "does not hijack an explicit generative provider" do
      ENV["TYPESAFE_API_KEY"] = "ts-env"

      expect { resolve(api_key: nil, provider: :openai) }.to raise_error(ArgumentError, /API key/)
    end
  end

  describe "tier 7: unrecognised key with a jev model or strategy" do
    it "routes a jev model to TypeSafe Direct" do
      expect(resolve(api_key: "ts-key", model: "jev-1.13.0").model).to eq("jev-1.13.0")
      expect(resolve(api_key: "ts-key", model: "jev-1.13.0").gateway).to eq(:typesafe)
    end

    it "routes an explicit strategy to TypeSafe Direct" do
      r = resolve(api_key: "ts-key", strategy: "bogo")

      expect([r.provider, r.model]).to eq([:jev, "jev-latest"])
    end
  end

  describe "validation" do
    it "rejects strategy: with a generative provider" do
      expect { resolve(api_key: "sk-1", provider: :openai, strategy: :bogo) }
        .to raise_error(VibeSort::ConfigurationError, /only supported by System One/)
    end

    it "rejects an unknown strategy" do
      expect { resolve(api_key: "ts", provider: :jev, strategy: :quick) }
        .to raise_error(VibeSort::ConfigurationError, /Unknown strategy/)
    end
  end
end
