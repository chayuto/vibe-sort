# frozen_string_literal: true

module VibeSort
  # Process-wide defaults for System One (Jev) sorting. Individual clients and
  # individual sort calls override these.
  #
  #   VibeSort.configure do |c|
  #     c.jev_max_retries = 5
  #     c.jev_long_context = true
  #   end
  class Settings
    DEFAULT_TYPESAFE_URL = "https://api.typesafe.ai"

    attr_writer :typesafe_api_key, :typesafe_base_url
    attr_accessor :jev_model, :jev_strategy, :jev_long_context, :jev_max_retries, :jev_timeout,
                  :jev_shuffle_options, :jev_tie_break, :jev_tie_epsilon, :jev_confidence_floor,
                  :jev_bogo_max_attempts, :jev_bogo_threshold, :openrouter_referer, :openrouter_title

    def initialize
      @typesafe_api_key = nil
      @typesafe_base_url = nil
      @jev_model = nil # nil = the gateway's own default (jev-latest / ~typesafe/jev-latest)
      @jev_strategy = :choice
      @jev_long_context = false
      @jev_max_retries = 3
      @jev_timeout = 30
      @jev_shuffle_options = true
      @jev_tie_break = true
      @jev_tie_epsilon = 0.15
      @jev_confidence_floor = 0.60
      @jev_bogo_max_attempts = 25
      @jev_bogo_threshold = 0.90
      @openrouter_referer = nil
      @openrouter_title = "vibe-sort"
    end

    # Falls back to ENV at read time so late-set environment variables are honoured.
    def typesafe_api_key
      blank_to_nil(@typesafe_api_key || ENV.fetch("TYPESAFE_API_KEY", nil))
    end

    def typesafe_base_url
      blank_to_nil(@typesafe_base_url || ENV.fetch("TYPESAFE_BASE_URL", nil)) || DEFAULT_TYPESAFE_URL
    end

    # @return [Hash] the per-sort option names used by the System One strategies
    def to_options
      {
        strategy: jev_strategy, long_context: jev_long_context, max_retries: jev_max_retries,
        timeout: jev_timeout, shuffle_options: jev_shuffle_options, tie_break: jev_tie_break,
        tie_epsilon: jev_tie_epsilon, confidence_floor: jev_confidence_floor,
        max_attempts: jev_bogo_max_attempts, threshold: jev_bogo_threshold,
        openrouter_referer: openrouter_referer, openrouter_title: openrouter_title
      }
    end

    private

    def blank_to_nil(value)
      stripped = value&.to_s&.strip
      stripped.nil? || stripped.empty? ? nil : stripped
    end
  end

  class << self
    def settings
      @settings ||= Settings.new
    end

    def configure
      yield settings
      settings
    end

    def reset_settings!
      @settings = Settings.new
    end
  end
end
