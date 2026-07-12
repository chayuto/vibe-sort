# frozen_string_literal: true

RSpec.describe VibeSort::Providers::OpenRouter do
  let(:client) { VibeSort::Client.new(api_key: "test-key", provider: :openrouter) }
  let(:endpoint) { "https://openrouter.ai/api/v1/chat/completions" }

  def success_body(sorted_array)
    {
      choices: [
        { message: { content: { sorted_array: sorted_array }.to_json } }
      ]
    }.to_json
  end

  it "sorts an array via OpenRouter's OpenAI-compatible API" do
    stub = stub_request(:post, endpoint)
           .with(
             headers: {
               "Authorization" => "Bearer test-key",
               "HTTP-Referer" => "https://github.com/chayuto/vibe-sort",
               "X-Title" => "vibe-sort"
             },
             body: hash_including(
               "model" => "openai/gpt-4o-mini",
               "response_format" => { "type" => "json_object" }
             )
           )
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1, 2, "a"]))

    result = client.sort([2, "a", 1])

    expect(result).to eq(success: true, sorted_array: [1, 2, "a"])
    expect(stub).to have_been_requested
  end

  it "uses a custom model when configured" do
    client = VibeSort::Client.new(api_key: "test-key", provider: :openrouter, model: "meta-llama/llama-3.3-70b-instruct")

    stub = stub_request(:post, endpoint)
           .with(body: hash_including("model" => "meta-llama/llama-3.3-70b-instruct"))
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1]))

    client.sort([1])

    expect(stub).to have_been_requested
  end

  it "is selected automatically for sk-or- prefixed keys" do
    client = VibeSort::Client.new(api_key: "sk-or-v1-abc123")

    stub = stub_request(:post, endpoint)
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1]))

    client.sort([1])

    expect(stub).to have_been_requested
  end

  it "returns an error result when the API fails" do
    stub_request(:post, endpoint)
      .to_return(
        status: 429,
        headers: { "Content-Type" => "application/json" },
        body: { error: { message: "Rate limit exceeded: free-models-per-min" } }.to_json
      )

    result = client.sort([1, 2, 3])

    expect(result[:success]).to be(false)
    expect(result[:error]).to eq("OpenRouter API error: Rate limit exceeded: free-models-per-min")
  end
end
