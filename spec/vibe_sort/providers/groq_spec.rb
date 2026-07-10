# frozen_string_literal: true

RSpec.describe VibeSort::Providers::Groq do
  let(:client) { VibeSort::Client.new(api_key: "test-key", provider: :groq) }
  let(:endpoint) { "https://api.groq.com/openai/v1/chat/completions" }

  def success_body(sorted_array)
    {
      choices: [
        { message: { content: { sorted_array: sorted_array }.to_json } }
      ]
    }.to_json
  end

  it "sorts an array via Groq's OpenAI-compatible API" do
    stub = stub_request(:post, endpoint)
           .with(
             headers: { "Authorization" => "Bearer test-key" },
             body: hash_including(
               "model" => "llama-3.3-70b-versatile",
               "response_format" => { "type" => "json_object" }
             )
           )
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1, 2, "a"]))

    result = client.sort([2, "a", 1])

    expect(result).to eq(success: true, sorted_array: [1, 2, "a"])
    expect(stub).to have_been_requested
  end

  it "returns an error result when the API fails" do
    stub_request(:post, endpoint)
      .to_return(
        status: 401,
        headers: { "Content-Type" => "application/json" },
        body: { error: { message: "Invalid API Key" } }.to_json
      )

    result = client.sort([1, 2, 3])

    expect(result[:success]).to be(false)
    expect(result[:error]).to eq("Groq API error: Invalid API Key")
  end
end
