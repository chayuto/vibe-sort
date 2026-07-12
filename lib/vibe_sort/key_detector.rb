# frozen_string_literal: true

module VibeSort
  # Best-effort provider inference from API key prefixes.
  #
  # Prefixes are conventions, not contracts — providers ship multiple key
  # formats concurrently (Google: "AIza..." and "AQ...."; OpenAI: "sk-..."
  # and "sk-proj-...") and new formats appear without notice. Detection is
  # therefore only a soft default and a source of non-fatal mismatch
  # warnings, never validation: an unrecognized prefix means "no inference",
  # not "bad key".
  module KeyDetector
    # Ordered: more specific prefixes must come before "sk-"
    PREFIXES = {
      "sk-ant-" => :anthropic,
      "sk-or-" => :openrouter,
      "sk-" => :openai,
      "gsk_" => :groq,
      "AIza" => :gemini,
      "AQ." => :gemini,
      "xai-" => :spacexai
    }.freeze

    # @param api_key [String] API key to inspect
    # @return [Symbol, nil] detected provider, or nil if the prefix is unrecognized
    def self.detect(api_key)
      PREFIXES.each { |prefix, provider| return provider if api_key.start_with?(prefix) }
      nil
    end
  end
end
