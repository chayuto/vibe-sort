# frozen_string_literal: true

require "vibe_sort"
require "webmock/rspec"

Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Keep examples hermetic: provider routing reads these from the environment
  config.around do |example|
    saved = ENV.values_at("TYPESAFE_API_KEY", "TYPESAFE_BASE_URL")
    ENV.delete("TYPESAFE_API_KEY")
    ENV.delete("TYPESAFE_BASE_URL")
    VibeSort.reset_settings!
    example.run
  ensure
    ENV["TYPESAFE_API_KEY"], ENV["TYPESAFE_BASE_URL"] = saved
    ENV.delete("TYPESAFE_API_KEY") if saved[0].nil?
    ENV.delete("TYPESAFE_BASE_URL") if saved[1].nil?
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
