# Architecture Overview

## System Design

VibeSort follows a layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│         User Application                │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│      VibeSort::Client (Public API)      │
│  - Input validation                     │
│  - Error handling                       │
│  - Response formatting                  │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│    VibeSort::Configuration              │
│  - Provider selection (explicit or      │
│    inferred via KeyDetector)            │
│  - API key management                   │
│  - Model override, extra_params         │
│  - Temperature settings                 │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│      VibeSort::Sorter (dispatcher)      │
│  - Picks the provider adapter           │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│   VibeSort::Providers::Base             │
│  - Shared prompt                        │
│  - HTTP client (Faraday)                │
│  - extra_params deep merge              │
│  - Response parsing & validation        │
├─────────────────────────────────────────┤
│  OpenAI │ Anthropic │ Gemini │          │
│  Groq   │ SpaceXAI  │ OpenRouter        │
│  (request/response wire formats)        │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│      Provider API (HTTPS)               │
│  api.openai.com │ api.anthropic.com     │
│  generativelanguage.googleapis.com      │
│  api.groq.com   │ api.x.ai              │
│  openrouter.ai                          │
└─────────────────────────────────────────┘
```

## Component Details

### VibeSort::Client

**Purpose**: Public-facing interface that users interact with.

**Responsibilities**:
- Initialize configuration
- Validate input arrays (must be non-empty arrays of numbers)
- Delegate sorting to `Sorter`
- Catch and format exceptions
- Return standardized response hashes

**Key Methods**:
- `initialize(api_key:, temperature: 0.0, provider: nil, model: nil, extra_params: {})`: Creates client with configuration
- `sort(array)`: Sorts array and returns result hash

**Return Format**:
```ruby
{
  success: Boolean,
  sorted_array: Array<Numeric>,
  error: String (only on failure)
}
```

### VibeSort::Configuration

**Purpose**: Encapsulates configuration settings.

**Responsibilities**:
- Resolve the provider: explicit argument wins (with a non-fatal stderr warning on a mismatched key prefix); otherwise inferred from the key prefix via `KeyDetector`, defaulting to `:openai`
- Store API key, model override, temperature, and extra_params
- Validate API key presence and provider name

**Key Methods**:
- `initialize(api_key:, temperature: 0.0, provider: nil, model: nil, extra_params: {})`: Creates configuration
- Raises `ArgumentError` if API key is nil/empty or an explicit provider is unknown

**Attributes**:
- `api_key`: Provider API key (String)
- `provider`: `:openai`, `:anthropic`, `:gemini`, `:groq`, `:spacexai`, or `:openrouter` (Symbol)
- `model`: Model ID override, or nil for the provider default (String or nil)
- `temperature`: Model temperature (Float, 0.0-2.0; not sent to Anthropic)
- `extra_params`: Provider-native request parameters deep-merged into the payload last (Hash)

### VibeSort::KeyDetector

**Purpose**: Best-effort provider inference from API key prefixes (`sk-ant-` → `:anthropic`, `sk-or-` → `:openrouter`, `gsk_` → `:groq`, `AIza`/`AQ.` → `:gemini`, `xai-` → `:spacexai`, `sk-` → `:openai`).

Prefixes are conventions, not contracts — providers ship multiple key formats concurrently and new formats appear without notice. Detection is therefore only a soft default and a source of non-fatal warnings, never validation: `detect` returns nil for unrecognized formats, and callers fall back to `:openai`.

### VibeSort::Sorter

**Purpose**: Dispatches the sort to the configured provider adapter.

**Key Methods**:
- `initialize(config)`: Creates sorter with configuration
- `perform(array)`: Looks up the adapter in `PROVIDER_CLASSES` and delegates

### VibeSort::Providers

**Purpose**: One adapter per LLM provider, all sharing a common base.

**`Providers::Base` responsibilities**:
- Hold the shared sorting prompt
- Build the HTTP connection with Faraday
- Deep-merge `config.extra_params` into the adapter payload last (nested hashes merge recursively; arrays and scalars replace)
- Parse and validate JSON responses (shared across providers)
- Raise `ApiError` on failures

**Adapter hooks** (implemented per provider): `provider_name`, `endpoint`, `headers`, `build_payload`, `extract_content`

**Adapters and default models**:
- `Providers::OpenAI`: Chat Completions, `gpt-4o-mini`
- `Providers::Anthropic`: Messages API with structured outputs (JSON schema), `claude-opus-4-8`
- `Providers::Gemini`: generateContent with JSON response mode, `gemini-2.5-flash`
- `Providers::Groq`: OpenAI-compatible (subclasses `Providers::OpenAI`), `llama-3.3-70b-versatile`
- `Providers::SpaceXAI`: OpenAI-compatible (subclasses `Providers::OpenAI`), `grok-4`
- `Providers::OpenRouter`: OpenAI-compatible (subclasses `Providers::OpenAI`), `openai/gpt-4o-mini`, adds OpenRouter's recommended attribution headers

### VibeSort::ApiError

**Purpose**: Custom exception for API-related errors.

**Responsibilities**:
- Encapsulate error message
- Store HTTP response for debugging
- Provide clear error context

**Attributes**:
- `message`: Error description (String)
- `response`: Faraday::Response object (optional)

## Request Flow

1. **User calls `client.sort([34, 1, 99, 15, 8])`**

2. **Client validates input**
   - Checks if input is an Array
   - Checks if all elements are Numeric
   - Returns error hash if invalid

3. **Client creates Sorter**
   - Passes Configuration object
   - Sorter picks the provider adapter, which initializes a Faraday connection

4. **Adapter builds the provider-specific request payload** (OpenAI example)
   ```json
   {
     "model": "gpt-4o-mini",
     "temperature": 0.0,
     "response_format": { "type": "json_object" },
     "messages": [
       {
         "role": "system",
         "content": "You are an assistant that only sorts..."
       },
       {
         "role": "user",
         "content": "Please sort this array: [34,1,99,15,8]"
       }
     ]
   }
   ```

5. **Adapter sends POST request**
   - URL: the adapter's endpoint (e.g. `https://api.openai.com/v1/chat/completions`)
   - Headers: provider auth (Bearer token, `x-api-key`, or `x-goog-api-key`), Content-Type
   - Body: JSON payload

6. **Provider processes request**
   - Model analyzes the array
   - Returns JSON with sorted array

7. **Adapter parses response** (OpenAI example)
   ```json
   {
     "choices": [{
       "message": {
         "content": "{\"sorted_array\": [1,8,15,34,99]}"
       }
     }]
   }
   ```

8. **Sorter validates result**
   - Checks if `sorted_array` key exists
   - Validates all elements are Numeric
   - Raises `ApiError` if invalid

9. **Client returns success hash**
   ```ruby
   {
     success: true,
     sorted_array: [1, 8, 15, 34, 99]
   }
   ```

## Error Handling

### Input Validation Errors
```ruby
# Empty array
{ success: false, sorted_array: [], error: "Input must be an array of numbers" }

# Non-array input
{ success: false, sorted_array: [], error: "Input must be an array of numbers" }

# Mixed types
{ success: false, sorted_array: [], error: "Input must be an array of numbers" }
```

### API Errors
```ruby
# Invalid API key
{ success: false, sorted_array: [], error: "OpenAI API error: Invalid API key" }

# Rate limit
{ success: false, sorted_array: [], error: "OpenAI API error: Rate limit exceeded" }

# Network error
{ success: false, sorted_array: [], error: "Unexpected error: Connection failed" }
```

### Response Parsing Errors
```ruby
# Invalid JSON
{ success: false, sorted_array: [], error: "Failed to parse JSON response: ..." }

# Missing sorted_array key
{ success: false, sorted_array: [], error: "Response does not contain a valid 'sorted_array'" }

# Non-numeric values
{ success: false, sorted_array: [], error: "Sorted array contains non-numeric values" }
```

## Dependencies

### Runtime
- **faraday** (~> 2.0): HTTP client library, the only runtime dependency; all providers are called over plain HTTPS

### Development
- **rspec** (~> 3.0): Testing framework
- **pry** (~> 0.14): Debugging console

## Design Decisions

### Why JSON Mode / Structured Outputs?
Each adapter uses the strongest JSON guarantee its provider offers: OpenAI-compatible providers use JSON mode (`response_format: { type: "json_object" }`), Anthropic uses structured outputs with a JSON schema, and Gemini uses `responseMimeType: "application/json"`. This makes parsing reliable across providers.

### Why Raw HTTP Instead of Provider SDKs?
Three simple JSON POSTs don't justify three SDK dependencies. Keeping everything on Faraday keeps the gem lightweight and the adapters symmetric.

### Why Temperature 0.0 by Default?
Lower temperature (0.0) produces deterministic, consistent results. Sorting should be predictable, not creative!

### Why Faraday?
Faraday is a flexible, well-maintained HTTP client with middleware support, making it easy to add JSON encoding/decoding.

### Why Separate Client and Sorter?
Separation of concerns:
- **Client**: User-facing API, input validation, error formatting
- **Sorter**: HTTP communication, response parsing, API logic

This makes testing easier and keeps responsibilities clear.

## Testing Strategy

### Unit Tests
- Test each class in isolation
- Mock HTTP requests (use WebMock or VCR)
- Test error conditions
- Validate input/output formats

### Integration Tests
- Test full flow with real API (use test API key)
- Verify correct request format
- Verify response parsing
- Test various array sizes

### Edge Cases
- Empty arrays
- Single-element arrays
- Already sorted arrays
- Reverse-sorted arrays
- Duplicate values
- Negative numbers
- Floating-point numbers
- Very large numbers

## Security Considerations

1. **API Key Storage**: Never hardcode API keys. Use environment variables.
2. **Input Validation**: Always validate user input before sending to API.
3. **Output Validation**: Verify API responses before returning to user.
4. **Error Messages**: Don't expose sensitive information in error messages.
5. **HTTPS**: All API communication uses HTTPS (encrypted).

## Performance Considerations

### Latency
- Each sort requires an API round-trip (~1-3 seconds)
- Network latency varies by location
- OpenAI API processing time varies by load

### Cost
- OpenAI charges per token
- Each sort uses approximately 100-200 tokens
- Cost: ~$0.001-0.002 per sort (with gpt-3.5-turbo)

### Rate Limits
- OpenAI enforces rate limits (requests per minute)
- Free tier: 3 requests/minute
- Paid tier: 60+ requests/minute

### Scalability
- Not suitable for high-frequency sorting
- Consider batching if sorting multiple arrays
- Add caching if sorting same arrays repeatedly

## Future Enhancements

Potential improvements for future versions:

1. **Batch Sorting**: Sort multiple arrays in one API call
2. **Caching**: Cache results for identical inputs
3. **Retry Logic**: Automatic retry on transient failures
5. **Async Support**: Non-blocking API calls with callbacks
6. **Metrics**: Track API usage, costs, and performance
7. **Different Sort Orders**: Support descending order
8. **Custom Sorting**: Allow custom comparison functions
