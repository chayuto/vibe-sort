# frozen_string_literal: true

RSpec.describe VibeSort::SystemOne::Client do
  let(:direct_url) { "https://api.typesafe.ai/v1/systemone" }
  let(:openrouter_url) { "https://openrouter.ai/api/v1/systemone" }
  let(:sleeps) { [] }
  let(:ok_body) { systemone_body({ "q" => noul_answer(0.9) }) }
  let(:state) { { "k" => "v" } }
  let(:questions) { { "q" => { "type" => "noul", "instructions" => "?" } } }

  def build(**overrides)
    described_class.new(
      api_key: " ts-key ", base_url: "https://api.typesafe.ai/", model: "jev-latest",
      sleeper: ->(seconds) { sleeps << seconds }, jitter: -> { 1.0 }, **overrides
    )
  end

  def query(client = build)
    client.query(state: state, questions: questions)
  end

  describe "request" do
    it "posts the exact envelope and headers to TypeSafe Direct" do
      stub = stub_request(:post, direct_url).with(
        body: { "model" => "jev-latest", "state" => state, "questions" => questions },
        headers: {
          "Authorization" => "Bearer ts-key", "Content-Type" => "application/json", "Accept" => "application/json",
          "User-Agent" => "vibe-sort/#{VibeSort::VERSION} (Ruby/#{RUBY_VERSION})"
        }
      ).to_return(status: 200, body: ok_body)

      response = query

      expect(stub).to have_been_requested
      expect(response.model).to eq("jev-1.14.0")
      expect(response.answers["q"]["noul"]).to eq(0.9)
      expect(response.usage).to eq("input_tokens" => 5, "output_tokens" => 1)
    end

    it "targets OpenRouter and sends attribution headers only there" do
      stub = stub_request(:post, openrouter_url)
             .with(headers: { "HTTP-Referer" => "https://example.test", "X-Title" => "my-app" })
             .to_return(status: 200, body: ok_body)
      client = described_class.new(api_key: "sk-or-v1-x", base_url: "https://openrouter.ai/api", model: "~typesafe/jev-latest",
                                   referer: "https://example.test", title: "my-app")

      query(client)

      expect(stub).to have_been_requested
    end

    it "omits OpenRouter attribution headers on TypeSafe Direct" do
      stub = stub_request(:post, direct_url).to_return(status: 200, body: ok_body)

      query(build(referer: "https://example.test", title: "my-app"))

      expect(WebMock).to(have_requested(:post, direct_url).with { |req| !req.headers.key?("Http-Referer") && !req.headers.key?("X-Title") })
      expect(stub).to have_been_requested
    end

    it "sends the long-context header only when enabled" do
      stub_request(:post, direct_url).to_return(status: 200, body: ok_body)

      query(build(long_context: true))
      query(build(long_context: false))

      expect(WebMock).to have_requested(:post, direct_url).with(headers: { "TypeSafe-Danger-Zone-Long-Context" => "true" }).once
      expect(WebMock).to have_requested(:post, direct_url).twice
    end

    it "sanitises the payload (NaN would otherwise break JSON)" do
      stub_request(:post, direct_url).to_return(status: 200, body: ok_body)

      client = build
      client.query(state: { "n" => Float::NAN }, questions: questions)

      expect(WebMock).to have_requested(:post, direct_url).with(body: hash_including("state" => { "n" => "NaN" }))
    end

    it "raises ConfigurationError for a blank key" do
      expect { described_class.new(api_key: "  ", base_url: "x", model: "m") }.to raise_error(VibeSort::ConfigurationError)
    end

    it "refuses payloads over 32 MiB without making a request" do
      big = "x" * ((32 * 1024 * 1024) + 1)

      expect { build.query(state: { "blob" => big }, questions: questions) }.to raise_error(VibeSort::PayloadTooLargeError)
      expect(WebMock).not_to have_requested(:post, direct_url)
    end

    it "tolerates unknown fields in OpenRouter-style responses" do
      stub_request(:post, direct_url).to_return(
        status: 200,
        body: systemone_body({ "q" => noul_answer(0.5) }, usage: { "input_tokens" => 3, "output_tokens" => 1, "cost" => 0.0001 },
                                                          id: "gen-1", provider: "TypeSafe")
      )

      expect(query.usage).to include("cost" => 0.0001)
    end
  end

  describe "retries" do
    it "retries 429, 524 and 529, then succeeds" do
      stub_request(:post, direct_url).to_return({ status: 429 }, { status: 524 }, { status: 529 }, { status: 200, body: ok_body })

      expect(query.answers).to have_key("q")
      expect(WebMock).to have_requested(:post, direct_url).times(4)
      expect(sleeps).to eq([0.5, 1.0, 2.0])
    end

    it "honours a numeric Retry-After header" do
      stub_request(:post, direct_url).to_return({ status: 429, headers: { "Retry-After" => "7" } }, { status: 200, body: ok_body })

      query

      expect(sleeps).to eq([7.0])
    end

    it "ignores an excessive Retry-After and backs off instead" do
      stub_request(:post, direct_url).to_return({ status: 429, headers: { "Retry-After" => "600" } }, { status: 200, body: ok_body })

      query

      expect(sleeps).to eq([0.5])
    end

    it "raises RateLimitError once retries are exhausted" do
      stub_request(:post, direct_url).to_return(status: 429, body: '{"error":{"message":"slow down"}}')

      expect { query(build(max_retries: 2)) }.to raise_error(VibeSort::RateLimitError, /slow down/)
      expect(WebMock).to have_requested(:post, direct_url).times(3)
    end

    it "raises OverloadedError for exhausted 529s and ApiError for exhausted 524s" do
      stub_request(:post, direct_url).to_return(status: 529)
      expect { query(build(max_retries: 1)) }.to raise_error(VibeSort::OverloadedError)

      stub_request(:post, direct_url).to_return(status: 524)
      expect { query(build(max_retries: 1)) }.to raise_error(VibeSort::ApiError, /524/)
    end

    it "retries transient network errors" do
      stub_request(:post, direct_url).to_timeout.then.to_return(status: 200, body: ok_body)

      expect(query.answers).to have_key("q")
      expect(sleeps.size).to eq(1)
    end

    it "gives up on persistent network errors with an ApiError" do
      stub_request(:post, direct_url).to_timeout

      expect { query(build(max_retries: 1)) }.to raise_error(VibeSort::ApiError, /request failed/)
    end

    it "does not retry client errors" do
      { 400 => VibeSort::ValidationError, 401 => VibeSort::AuthenticationError, 402 => VibeSort::PaymentRequiredError,
        403 => VibeSort::AuthorizationError, 413 => VibeSort::PayloadTooLargeError, 415 => VibeSort::ApiError,
        422 => VibeSort::ValidationError }.each do |status, error|
        WebMock.reset!
        stub_request(:post, direct_url).to_return(status: status, body: '{"error":{"message":"nope"}}',
                                                  headers: { "Content-Type" => "application/json" })

        expect { query }.to raise_error(error, /nope/)
        expect(WebMock).to have_requested(:post, direct_url).once
      end
      expect(sleeps).to be_empty
    end
  end

  describe "error mapping" do
    it "maps 400 max_tokens_exceeded to ContextLengthError with a long_context hint" do
      stub_request(:post, direct_url).to_return(status: 400, body: '{"error":{"message":"max_tokens_exceeded: 70000"}}')

      expect { query }.to raise_error(VibeSort::ContextLengthError, /long_context: true/)
    end

    it "detects the Cloudflare HTML 403 without trying to parse it" do
      stub_request(:post, direct_url).to_return(
        status: 403, body: "<html>Attention Required! | Cloudflare</html>",
        headers: { "Content-Type" => "text/html", "cf-ray" => "8abc-SIN" }
      )

      expect { query }.to raise_error(VibeSort::EdgeFirewallError) { |e|
        expect(e.cf_ray).to eq("8abc-SIN")
        expect(e.message).to include("8abc-SIN")
      }
    end

    it "treats a non-JSON 403 carrying cf-ray as the edge firewall even without an HTML content type" do
      stub_request(:post, direct_url).to_return(status: 403, body: "blocked", headers: { "cf-ray" => "1" })

      expect { query }.to raise_error(VibeSort::EdgeFirewallError)
    end

    it "raises ApiError for a 200 with an invalid body" do
      stub_request(:post, direct_url).to_return(status: 200, body: "<html>")
      expect { query }.to raise_error(VibeSort::ApiError, /invalid JSON/)

      stub_request(:post, direct_url).to_return(status: 200, body: '{"nope":1}')
      expect { query }.to raise_error(VibeSort::ApiError, /unexpected response/)
    end
  end
end
