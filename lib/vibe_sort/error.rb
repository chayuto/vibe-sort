# frozen_string_literal: true

module VibeSort
  # Custom error class for API-related errors
  class ApiError < StandardError
    attr_reader :response

    # Initialize a new ApiError
    #
    # @param message [String] Error message
    # @param response [Faraday::Response, nil] HTTP response object
    def initialize(message, response = nil)
      super(message)
      @response = response
    end
  end

  # Spec-friendly alias: the gem has always spelled it +ApiError+
  APIError = ApiError

  # Raised for invalid or contradictory configuration. Subclasses ArgumentError so
  # callers that already rescue ArgumentError from Client.new keep working.
  class ConfigurationError < ArgumentError; end

  # --- TypeSafe System One (Jev) errors ---

  # HTTP 400 (other than context overflow) or 422: the request was malformed
  class ValidationError < ApiError; end

  # HTTP 400 +max_tokens_exceeded+: state + questions exceeded the context window
  class ContextLengthError < ApiError; end

  # Payload over TypeSafe's 32 MiB body limit (raised client-side, or on HTTP 413)
  class PayloadTooLargeError < ApiError; end

  # HTTP 401: invalid or missing API key
  class AuthenticationError < ApiError; end

  # HTTP 402 (OpenRouter): insufficient credits
  class PaymentRequiredError < ApiError; end

  # HTTP 403 with a JSON body
  class AuthorizationError < ApiError; end

  # HTTP 403 served as HTML by the Cloudflare edge (TypeSafe's WAF), usually because
  # the sorted values look like shell commands or URLs.
  class EdgeFirewallError < ApiError
    attr_reader :cf_ray

    def initialize(message, response = nil, cf_ray: nil)
      super(message, response)
      @cf_ray = cf_ray
    end
  end

  # HTTP 429 after retries were exhausted
  class RateLimitError < ApiError; end

  # HTTP 529 after retries were exhausted
  class OverloadedError < ApiError; end

  # Raised by the :bogo strategy in strict mode when no shuffle clears the threshold
  class BogoExhaustedError < StandardError
    attr_reader :attempts, :best_probability

    def initialize(attempts:, best_probability:)
      @attempts = attempts
      @best_probability = best_probability
      super("Vibe bogosort gave up after #{attempts} attempts (best sortedness probability: #{best_probability.round(3)})")
    end
  end
end
