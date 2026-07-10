# frozen_string_literal: true

RSpec.describe VibeSort::Providers::SpaceXAI do
  let(:client) { VibeSort::Client.new(api_key: "test-key", provider: :spacexai) }
  let(:endpoint) { "https://api.x.ai/v1/chat/completions" }

  def success_body(sorted_array)
    {
      choices: [
        { message: { content: { sorted_array: sorted_array }.to_json } }
      ]
    }.to_json
  end

  it "sorts an array via the SpaceXAI Grok API" do
    stub = stub_request(:post, endpoint)
           .with(
             headers: { "Authorization" => "Bearer test-key" },
             body: hash_including("model" => "grok-4")
           )
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1, 2, "a"]))

    result = client.sort([2, "a", 1])

    expect(result).to eq(success: true, sorted_array: [1, 2, "a"])
    expect(stub).to have_been_requested
  end

  it "uses a custom model when configured" do
    client = VibeSort::Client.new(api_key: "test-key", provider: :spacexai, model: "grok-4.5")

    stub = stub_request(:post, endpoint)
           .with(body: hash_including("model" => "grok-4.5"))
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1]))

    client.sort([1])

    expect(stub).to have_been_requested
  end

  it "returns an error result when the API fails" do
    stub_request(:post, endpoint)
      .to_return(
        status: 401,
        headers: { "Content-Type" => "application/json" },
        body: { error: { message: "Incorrect API key provided" } }.to_json
      )

    result = client.sort([1, 2, 3])

    expect(result[:success]).to be(false)
    expect(result[:error]).to eq("SpaceXAI API error: Incorrect API key provided")
  end
end
