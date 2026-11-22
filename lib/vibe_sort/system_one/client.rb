# frozen_string_literal: true

module VibeSort
  module SystemOne
    # HTTP transport for TypeSafe's POST /v1/systemone, which is wire-compatible
    # across TypeSafe Direct and OpenRouter.
    class Client
      MAX_BODY_BYTES = 32 * 1024 * 1024
      RETRYABLE_STATUSES = [429, 524, 529].freeze
      MAX_RETRY_AFTER = 30
      LONG_CONTEXT_HEADER = "TypeSafe-Danger-Zone-Long-Context"

      # Parsed System One response
      Response = Struct.new(:model, :answers, :usage, keyword_init: true)

      attr_reader :base_url, :model

      # @param api_key [String] bearer token
      # @param base_url [String] gateway root, e.g. https://api.typesafe.ai or https://openrouter.ai/api
      # @param model [String] System One model id
      # @param long_context [Boolean] opt in to the 262k context window
      # @param max_retries [Integer] retries for 429/524/529 and transient network errors
      # @param timeout [Numeric] per-request timeout in seconds
      # @param referer [String, nil] OpenRouter HTTP-Referer attribution header
      # @param title [String, nil] OpenRouter X-Title attribution header
      # @param sleeper [#call] receives seconds to wait between retries (injectable for tests)
      # @param jitter [#call] returns a multiplier in 0.5..1.0 for backoff (injectable for tests)
      def initialize(api_key:, base_url:, model:, long_context: false, max_retries: 3, timeout: 30,
                     referer: nil, title: nil, sleeper: ->(seconds) { sleep(seconds) }, jitter: -> { rand(0.5..1.0) })
        @api_key = api_key.to_s.strip
        raise ConfigurationError, "API key cannot be nil or empty" if @api_key.empty?

        @base_url = base_url
        @model = model
        @long_context = long_context
        @max_retries = max_retries
        @timeout = timeout
        @referer = referer
        @title = title
        @sleeper = sleeper
        @jitter = jitter
      end

      def url
        "#{base_url.to_s.sub(%r{/+\z}, "")}/v1/systemone"
      end

      # Ask one or more typed questions about a shared state.
      #
      # @param state [Object] anything JSON-serialisable (sanitised by Serializer)
      # @param questions [Hash{String => Hash}] opaque question id => question
      # @return [Response]
      def query(state:, questions:)
        body = JSON.generate(
          "model" => model,
          "state" => Serializer.call(state),
          "questions" => Serializer.call(questions)
        )
        raise PayloadTooLargeError, "System One request is #{body.bytesize} bytes, over the 32 MiB limit" if body.bytesize > MAX_BODY_BYTES

        parse(post_with_retries(body))
      end

      private

      def post_with_retries(body)
        attempt = 0
        loop do
          begin
            response = connection.post(url, body)
          rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
            raise ApiError, "System One request failed: #{e.message}" if attempt >= @max_retries

            wait(nil, attempt)
            attempt += 1
            next
          end

          return response if response.success?

          if RETRYABLE_STATUSES.include?(response.status) && attempt < @max_retries
            wait(response.headers["retry-after"], attempt)
            attempt += 1
            next
          end

          raise_for(response)
        end
      end

      def wait(retry_after, attempt)
        seconds = Float(retry_after, exception: false) if retry_after
        seconds = (0.5 * (2**attempt)) * @jitter.call unless seconds && seconds >= 0 && seconds <= MAX_RETRY_AFTER
        @sleeper.call(seconds)
      end

      def connection
        @connection ||= Faraday.new do |f|
          f.options.timeout = @timeout
          f.options.open_timeout = @timeout
          request_headers.each { |name, value| f.headers[name] = value }
          f.adapter Faraday.default_adapter
        end
      end

      def request_headers
        headers = {
          "Authorization" => "Bearer #{@api_key}",
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "User-Agent" => "vibe-sort/#{VibeSort::VERSION} (Ruby/#{RUBY_VERSION})"
        }
        headers[LONG_CONTEXT_HEADER] = "true" if @long_context
        if base_url.to_s.include?("openrouter.ai")
          headers["HTTP-Referer"] = @referer if @referer
          headers["X-Title"] = @title if @title
        end
        headers
      end

      def parse(response)
        data = JSON.parse(response.body.to_s)
        raise ApiError.new("System One returned an unexpected response shape", response) unless data.is_a?(Hash) && data["answers"].is_a?(Hash)

        usage = data["usage"].is_a?(Hash) ? data["usage"] : {}
        Response.new(model: data["model"] || model, answers: data["answers"], usage: usage)
      rescue JSON::ParserError => e
        raise ApiError.new("System One returned invalid JSON: #{e.message}", response)
      end

      def raise_for(response)
        status = response.status
        detail = error_detail(response)
        message = "System One API error (HTTP #{status}): #{detail}"

        case status
        when 400 then raise_bad_request(message, response)
        when 401 then raise AuthenticationError.new(message, response)
        when 402 then raise PaymentRequiredError.new(message, response)
        when 403 then raise_forbidden(message, response)
        when 413 then raise PayloadTooLargeError.new(message, response)
        when 422 then raise ValidationError.new(message, response)
        when 429 then raise RateLimitError.new(message, response)
        when 529 then raise OverloadedError.new(message, response)
        else raise ApiError.new(message, response)
        end
      end

      def raise_bad_request(message, response)
        raise ContextLengthError.new("#{message}. Try `long_context: true` or sort fewer items at once.", response) if response.body.to_s.include?("max_tokens_exceeded")

        raise ValidationError.new(message, response)
      end

      def raise_forbidden(message, response)
        headers = response.headers
        content_type = headers["content-type"].to_s
        cf_ray = headers["cf-ray"]
        if content_type.include?("text/html") || (cf_ray && !json?(response.body))
          raise EdgeFirewallError.new(
            "Blocked by the TypeSafe edge firewall (Cloudflare#{", cf-ray #{cf_ray}" if cf_ray}). " \
            "This usually means a sorted value looks like a shell command or URL.",
            response, cf_ray: cf_ray
          )
        end

        raise AuthorizationError.new(message, response)
      end

      def json?(body)
        JSON.parse(body.to_s)
        true
      rescue JSON::ParserError
        false
      end

      def error_detail(response)
        body = response.body.to_s
        parsed = JSON.parse(body)
        return body[0, 300] unless parsed.is_a?(Hash)

        error = parsed["error"]
        (error.is_a?(Hash) ? error["message"] : error) || parsed["message"] || body[0, 300]
      rescue JSON::ParserError
        body[0, 300]
      end
    end
  end
end
