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
│  - API key management                   │
│  - Temperature settings                 │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│      VibeSort::Sorter                   │
│  - HTTP client (Faraday)                │
│  - Request building                     │
│  - Response parsing                     │
│  - Validation                           │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│      OpenAI API                         │
│  https://api.openai.com/v1/chat/       │
│  completions                            │
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
- `initialize(api_key:, temperature: 0.0)`: Creates client with configuration
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
- Store API key securely
- Store temperature setting
- Validate API key presence

**Key Methods**:
- `initialize(api_key:, temperature:)`: Creates configuration
- Raises `ArgumentError` if API key is nil or empty

**Attributes**:
- `api_key`: OpenAI API key (String)
- `temperature`: Model temperature (Float, 0.0-2.0)

### VibeSort::Sorter

**Purpose**: Handles communication with OpenAI API.

**Responsibilities**:
- Build HTTP connection with Faraday
- Construct API request payload
- Send POST request to OpenAI
- Parse and validate JSON responses
- Extract sorted array from response
- Raise `ApiError` on failures

**Key Methods**:
- `initialize(config)`: Creates sorter with configuration
- `perform(array)`: Executes sort via API
- `build_payload(array)`: Private - constructs request
- `handle_response(response)`: Private - processes response
- `parse_sorted_array(response)`: Private - extracts result
- `validate_sorted_array!(array)`: Private - validates output

**Constants**:
- `OPENAI_API_URL`: API endpoint
- `DEFAULT_MODEL`: "gpt-3.5-turbo-1106" (supports JSON mode)

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
   - Sorter initializes Faraday connection

4. **Sorter builds request payload**
   ```json
   {
     "model": "gpt-3.5-turbo-1106",
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

5. **Sorter sends POST request**
   - URL: `https://api.openai.com/v1/chat/completions`
   - Headers: Authorization (Bearer token), Content-Type
   - Body: JSON payload

6. **OpenAI processes request**
   - Model analyzes the array
   - Returns JSON with sorted array

7. **Sorter parses response**
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
- **faraday** (~> 2.0): HTTP client library
- **faraday-json** (~> 1.0): JSON middleware for Faraday

### Development
- **rspec** (~> 3.0): Testing framework
- **pry** (~> 0.14): Debugging console

## Design Decisions

### Why JSON Mode?
OpenAI's JSON mode (`response_format: { type: "json_object" }`) ensures the model always returns valid JSON, making parsing more reliable.

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
3. **Custom Models**: Allow users to specify different GPT models
4. **Retry Logic**: Automatic retry on transient failures
5. **Async Support**: Non-blocking API calls with callbacks
6. **Metrics**: Track API usage, costs, and performance
7. **Different Sort Orders**: Support descending order
8. **Custom Sorting**: Allow custom comparison functions
