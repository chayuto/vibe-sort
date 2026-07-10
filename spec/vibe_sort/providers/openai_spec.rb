# frozen_string_literal: true

RSpec.describe VibeSort::Providers::OpenAI do
  let(:client) { VibeSort::Client.new(api_key: "test-key") }
  let(:endpoint) { "https://api.openai.com/v1/chat/completions" }

  def success_body(sorted_array)
    {
      choices: [
        { message: { content: { sorted_array: sorted_array }.to_json } }
      ]
    }.to_json
  end

  it "sorts an array via the Chat Completions API" do
    stub = stub_request(:post, endpoint)
           .with(
             headers: { "Authorization" => "Bearer test-key" },
             body: hash_including(
               "model" => "gpt-4o-mini",
               "temperature" => 0.0,
               "response_format" => { "type" => "json_object" }
             )
           )
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1, 2, "a"]))

    result = client.sort([2, "a", 1])

    expect(result).to eq(success: true, sorted_array: [1, 2, "a"])
    expect(stub).to have_been_requested
  end

  it "uses a custom model when configured" do
    client = VibeSort::Client.new(api_key: "test-key", model: "gpt-4.1-nano")

    stub = stub_request(:post, endpoint)
           .with(body: hash_including("model" => "gpt-4.1-nano"))
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1]))

    client.sort([1])

    expect(stub).to have_been_requested
  end

  it "returns an error result when the API fails" do
    stub_request(:post, endpoint)
      .to_return(
        status: 401,
        headers: { "Content-Type" => "application/json" },
        body: { error: { message: "Invalid API key" } }.to_json
      )

    result = client.sort([1, 2, 3])

    expect(result[:success]).to be(false)
    expect(result[:sorted_array]).to eq([])
    expect(result[:error]).to eq("OpenAI API error: Invalid API key")
  end

  it "returns an error result when the response contains invalid JSON" do
    stub_request(:post, endpoint)
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { choices: [{ message: { content: "not json" } }] }.to_json
      )

    result = client.sort([1, 2, 3])

    expect(result[:success]).to be(false)
    expect(result[:error]).to start_with("Failed to parse JSON response")
  end
end
