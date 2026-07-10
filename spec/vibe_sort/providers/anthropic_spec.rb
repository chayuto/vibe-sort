# frozen_string_literal: true

RSpec.describe VibeSort::Providers::Anthropic do
  let(:client) { VibeSort::Client.new(api_key: "test-key", provider: :anthropic) }
  let(:endpoint) { "https://api.anthropic.com/v1/messages" }

  def success_body(sorted_array)
    {
      content: [
        { type: "text", text: { sorted_array: sorted_array }.to_json }
      ]
    }.to_json
  end

  it "sorts an array via the Messages API" do
    stub = stub_request(:post, endpoint)
           .with(
             headers: { "x-api-key" => "test-key", "anthropic-version" => "2023-06-01" },
             body: hash_including(
               "model" => "claude-opus-4-8",
               "max_tokens" => 4096,
               "output_config" => hash_including("format" => hash_including("type" => "json_schema"))
             )
           )
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1, 2, "a"]))

    result = client.sort([2, "a", 1])

    expect(result).to eq(success: true, sorted_array: [1, 2, "a"])
    expect(stub).to have_been_requested
  end

  it "does not send the temperature parameter" do
    stub = stub_request(:post, endpoint)
           .with { |req| !JSON.parse(req.body).key?("temperature") }
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1]))

    client.sort([1])

    expect(stub).to have_been_requested
  end

  it "uses a custom model when configured" do
    client = VibeSort::Client.new(api_key: "test-key", provider: :anthropic, model: "claude-haiku-4-5")

    stub = stub_request(:post, endpoint)
           .with(body: hash_including("model" => "claude-haiku-4-5"))
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1]))

    client.sort([1])

    expect(stub).to have_been_requested
  end

  it "returns an error result when the API fails" do
    stub_request(:post, endpoint)
      .to_return(
        status: 401,
        headers: { "Content-Type" => "application/json" },
        body: { type: "error", error: { type: "authentication_error", message: "invalid x-api-key" } }.to_json
      )

    result = client.sort([1, 2, 3])

    expect(result[:success]).to be(false)
    expect(result[:sorted_array]).to eq([])
    expect(result[:error]).to eq("Anthropic API error: invalid x-api-key")
  end

  it "returns an error result when the response has no text block" do
    stub_request(:post, endpoint)
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { content: [] }.to_json
      )

    result = client.sort([1, 2, 3])

    expect(result[:success]).to be(false)
    expect(result[:error]).to eq("Invalid response structure")
  end
end
