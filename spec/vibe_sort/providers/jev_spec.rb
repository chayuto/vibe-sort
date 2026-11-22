# frozen_string_literal: true

RSpec.describe VibeSort::Providers::Jev do
  let(:direct_url) { "https://api.typesafe.ai/v1/systemone" }
  let(:openrouter_url) { "https://openrouter.ai/api/v1/systemone" }

  # Stubs Jev as an oracle that picks the alphabetically-first candidate
  def stub_alphabetical_choice(url)
    stub_request(:post, url).to_return do |request|
      body = JSON.parse(request.body)
      candidates = body["state"]["candidates"]
      key = body["questions"]["pick_next"]["criteria"].keys.min_by { |k| candidates[k].to_s }
      { status: 200, body: systemone_body({ "pick_next" => choice_answer(key) }), headers: { "Content-Type" => "application/json" } }
    end
  end

  describe "through VibeSort::Client with TypeSafe Direct" do
    let(:client) { VibeSort::Client.new(api_key: "ts-key", provider: :jev, shuffle_options: false) }

    it "returns the standard success hash from #sort" do
      stub_alphabetical_choice(direct_url)

      expect(client.sort(%w[pear apple fig])).to eq(success: true, sorted_array: %w[apple fig pear])
    end

    it "returns a Result with metadata from #sort_with_metadata" do
      stub_alphabetical_choice(direct_url)

      result = client.sort_with_metadata(%w[pear apple fig])

      expect(result).to be_a(VibeSort::Result)
      expect(result.items).to eq(%w[apple fig pear])
      expect([result.strategy, result.gateway, result.model, result.api_calls]).to eq([:choice, :typesafe, "jev-1.14.0", 2])
      expect(result.usage).to eq(input_tokens: 10, output_tokens: 2, cost: nil)
    end

    it "accepts any objects and preserves identity" do
      stub_alphabetical_choice(direct_url)
      item = { "name" => "fig" }
      other = { "name" => "apple" }

      result = client.sort_with_metadata([item, other])

      expect(result.items.first).to equal(other)
      expect(result.items.last).to equal(item)
    end

    it "accepts an empty array without calling the API" do
      expect(client.sort([])).to eq(success: true, sorted_array: [])
      expect(WebMock).not_to have_requested(:post, direct_url)
    end

    it "uses jev-latest and sends it in the request" do
      stub_alphabetical_choice(direct_url)

      client.sort(%w[b a])

      expect(WebMock).to have_requested(:post, direct_url).with(body: hash_including("model" => "jev-latest"))
    end

    it "reports API failures in the hash like the generative providers" do
      stub_request(:post, direct_url).to_return(status: 401, body: '{"error":{"message":"bad key"}}')

      result = client.sort(%w[b a])

      expect(result).to include(success: false, sorted_array: [])
      expect(result[:error]).to match(/bad key/)
    end

    it "raises from #sort_with_metadata" do
      stub_request(:post, direct_url).to_return(status: 401, body: "{}")

      expect { client.sort_with_metadata(%w[b a]) }.to raise_error(VibeSort::AuthenticationError)
    end

    it "overrides strategy, by and order per call" do
      stub_request(:post, direct_url).to_return do |request|
        questions = JSON.parse(request.body)["questions"]
        answers = questions.keys.each_with_index.to_h { |id, i| [id, score_answer(i.to_f)] }
        { status: 200, body: systemone_body(answers) }
      end

      result = client.sort_with_metadata(%w[x y z], strategy: :score, order: :desc, by: "zzz-ness", tie_break: false)

      expect(result.strategy).to eq(:score)
      expect(result.items).to eq(%w[z y x])
      expect(WebMock).to have_requested(:post, direct_url).with(body: /zzz-ness/)
    end

    it "supports prompt: as an alias for by:" do
      stub_alphabetical_choice(direct_url)

      client.sort(%w[b a], prompt: "alphabetical")

      expect(WebMock).to have_requested(:post, direct_url).with(body: /alphabetical/)
    end

    it "returns an error hash for bogo exhaustion in strict mode" do
      stub_request(:post, direct_url).to_return(status: 200, body: systemone_body({ "is_sorted" => noul_answer(0.1) }))

      result = client.sort(%w[c b a], strategy: :bogo, max_attempts: 2, strict: true)

      expect(result[:success]).to be(false)
      expect(result[:error]).to match(/gave up after 2 attempts/)
    end

    it "rejects unknown per-call options" do
      expect(client.sort(%w[b a], bogus: 1)).to include(success: false)
      expect { client.sort_with_metadata(%w[b a], bogus: 1) }.to raise_error(VibeSort::ConfigurationError, /bogus/)
    end

    it "sends the long-context header when enabled per call" do
      stub_alphabetical_choice(direct_url)

      client.sort(%w[b a], long_context: true)

      expect(WebMock).to have_requested(:post, direct_url).with(headers: { "TypeSafe-Danger-Zone-Long-Context" => "true" })
    end
  end

  describe "routing" do
    it "reads TYPESAFE_API_KEY and TYPESAFE_BASE_URL from the environment" do
      ENV["TYPESAFE_API_KEY"] = "ts-env"
      ENV["TYPESAFE_BASE_URL"] = "https://typesafe.example/"
      stub = stub_request(:post, "https://typesafe.example/v1/systemone")
             .with(headers: { "Authorization" => "Bearer ts-env" })
             .to_return(status: 200, body: systemone_body({ "pick_next" => choice_answer("i_1") }))

      expect(VibeSort::Client.new.sort(%w[b a])[:success]).to be(true)
      expect(stub).to have_been_requested
    end

    it "sends sk-or- keys with a jev model to OpenRouter's System One endpoint" do
      stub = stub_request(:post, openrouter_url)
             .with(headers: { "Authorization" => "Bearer sk-or-v1-abc", "X-Title" => "vibe-sort" },
                   body: hash_including("model" => "jev-latest"))
             .to_return(status: 200, body: systemone_body({ "pick_next" => choice_answer("i_1") }, id: "gen-1", provider: "TypeSafe"))

      client = VibeSort::Client.new(api_key: "sk-or-v1-abc", model: "jev-latest")

      expect(client.config.provider).to eq(:jev)
      expect(client.sort_with_metadata(%w[b a]).gateway).to eq(:openrouter)
      expect(stub).to have_been_requested
    end

    it "uses ~typesafe/jev-latest when only a strategy: selects Jev on OpenRouter" do
      client = VibeSort::Client.new(api_key: "sk-or-v1-abc", strategy: :noul)

      expect(client.config.model).to eq("~typesafe/jev-latest")
    end

    it "keeps plain sk-or- keys on the OpenRouter chat provider (0.4.0 behaviour)" do
      expect(VibeSort::Client.new(api_key: "sk-or-v1-abc").config.provider).to eq(:openrouter)
    end

    it "honours global settings and lets the client override them" do
      VibeSort.configure { |c| c.jev_strategy = :noul }
      client = VibeSort::Client.new(api_key: "ts", provider: :jev)
      stub_request(:post, direct_url).to_return(status: 200, body: systemone_body({ "a_before_b" => noul_answer(0.9), "is_sorted" => noul_answer(0.95) }))

      expect(client.sort_with_metadata(%w[a b]).strategy).to eq(:noul)
      expect(client.sort_with_metadata(%w[a b], strategy: :bogo).strategy).to eq(:bogo)
    end
  end

  describe "configuration errors" do
    it "rejects strategy: with a generative provider at construction time" do
      expect { VibeSort::Client.new(api_key: "sk-1", provider: :openai, strategy: :bogo) }
        .to raise_error(VibeSort::ConfigurationError, /only supported by System One/)
    end

    it "rejects Jev-only options on generative providers" do
      expect { VibeSort::Client.new(api_key: "sk-1", provider: :openai, long_context: true) }
        .to raise_error(VibeSort::ConfigurationError, /only supported by System One/)
    end

    it "rejects Jev-only per-call options on generative providers" do
      client = VibeSort::Client.new(api_key: "sk-1")

      expect(client.sort([1], order: :desc)).to include(success: false, error: /only supported by System One/)
    end

    it "explains that sort_with_metadata needs System One" do
      client = VibeSort::Client.new(api_key: "sk-1")

      expect { client.sort_with_metadata([1]) }.to raise_error(VibeSort::ConfigurationError, /requires a System One/)
    end

    it "rejects unknown client options" do
      expect { VibeSort::Client.new(api_key: "ts", provider: :jev, nonsense: 1) }.to raise_error(VibeSort::ConfigurationError)
    end
  end

  describe "backwards compatibility" do
    it "still requires a non-empty array of numbers/strings for generative providers" do
      client = VibeSort::Client.new(api_key: "sk-1")

      expect(client.sort([])).to include(success: false)
      expect(client.sort([:sym])).to include(success: false, error: "Input must be an array of numbers or strings")
    end
  end
end
