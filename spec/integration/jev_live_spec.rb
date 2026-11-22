# frozen_string_literal: true

# Opt-in smoke tests against the real System One API. They cost (a fraction of) a cent:
#
#   LIVE_JEV_TESTS=1 TYPESAFE_API_KEY=... bundle exec rspec spec/integration/jev_live_spec.rb
#   LIVE_JEV_TESTS=1 OPENROUTER_API_KEY=sk-or-v1-... bundle exec rspec spec/integration/jev_live_spec.rb
#
# The live run must NOT go through the WebMock-blocked default, so it re-enables net connections.
if ENV["LIVE_JEV_TESTS"] == "1"
  RSpec.describe "Jev live smoke tests" do
    around do |example|
      WebMock.allow_net_connect!
      example.run
    ensure
      WebMock.disable_net_connect!
    end

    gateways = {
      "TypeSafe Direct" => -> { ENV.fetch("TYPESAFE_API_KEY", nil) && { api_key: ENV.fetch("TYPESAFE_API_KEY"), provider: :jev } },
      "OpenRouter" => -> { ENV.fetch("OPENROUTER_API_KEY", nil) && { api_key: ENV.fetch("OPENROUTER_API_KEY"), model: "jev-latest" } }
    }

    gateways.each do |name, credentials|
      context "via #{name}" do
        let(:client_options) { credentials.call or skip("no credentials for #{name}") }
        let(:items) { %w[ant elephant mouse whale] }

        %i[choice score noul bogo].each do |strategy|
          it "sorts four animals by size with :#{strategy}" do
            extra = strategy == :bogo ? { max_attempts: 10 } : {}
            client = VibeSort::Client.new(**client_options)

            result = client.sort_with_metadata(items, by: "size, smallest first", strategy: strategy, **extra)

            expect(result.items).to match_array(items)
            expect(result.items.map(&:object_id)).to match_array(items.map(&:object_id))
            expect(result.api_calls).to be >= 1
            expect(result.model).to match(/jev/)
            puts "#{name} #{strategy}: #{result.items.inspect} (#{result.api_calls} calls, #{result.warnings.size} warnings)"
          end
        end
      end
    end
  end
end
