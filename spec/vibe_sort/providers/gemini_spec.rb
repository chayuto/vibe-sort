# frozen_string_literal: true

RSpec.describe VibeSort::Providers::Gemini do
  let(:client) { VibeSort::Client.new(api_key: "test-key", provider: :gemini) }
  let(:endpoint) { "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" }

  def success_body(sorted_array)
    {
      candidates: [
        { content: { parts: [{ text: { sorted_array: sorted_array }.to_json }] } }
      ]
    }.to_json
  end

  it "sorts an array via the generateContent API" do
    stub = stub_request(:post, endpoint)
           .with(
             headers: { "x-goog-api-key" => "test-key" },
             body: hash_including(
               "generationConfig" => {
                 "temperature" => 0.0,
                 "responseMimeType" => "application/json"
               }
             )
           )
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1, 2, "a"]))

    result = client.sort([2, "a", 1])

    expect(result).to eq(success: true, sorted_array: [1, 2, "a"])
    expect(stub).to have_been_requested
  end

  it "embeds a custom model in the endpoint URL" do
    client = VibeSort::Client.new(api_key: "test-key", provider: :gemini, model: "gemini-2.5-pro")
    custom_endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"

    stub = stub_request(:post, custom_endpoint)
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1]))

    client.sort([1])

    expect(stub).to have_been_requested
  end

  it "deep-merges nested extra_params into generationConfig" do
    client = VibeSort::Client.new(api_key: "test-key", provider: :gemini,
                                  extra_params: { generationConfig: { maxOutputTokens: 256 } })

    stub = stub_request(:post, endpoint)
           .with(
             body: hash_including(
               "generationConfig" => {
                 "temperature" => 0.0,
                 "responseMimeType" => "application/json",
                 "maxOutputTokens" => 256
               }
             )
           )
           .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: success_body([1]))

    client.sort([1])

    expect(stub).to have_been_requested
  end

  it "returns an error result when the API fails" do
    stub_request(:post, endpoint)
      .to_return(
        status: 400,
        headers: { "Content-Type" => "application/json" },
        body: { error: { code: 400, message: "API key not valid", status: "INVALID_ARGUMENT" } }.to_json
      )

    result = client.sort([1, 2, 3])

    expect(result[:success]).to be(false)
    expect(result[:sorted_array]).to eq([])
    expect(result[:error]).to eq("Gemini API error: API key not valid")
  end
end
