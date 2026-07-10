# API Reference

## VibeSort::Client

The main public interface for the VibeSort gem.

### Class Methods

#### `new(api_key:, temperature: 0.0, provider: :openai, model: nil)`

Creates a new VibeSort client instance.

**Parameters:**

- `api_key` (String, required): API key for the selected provider
- `temperature` (Float, optional): Model temperature setting (default: 0.0)
  - Range: 0.0 to 2.0
  - Lower values (0.0-0.3): More deterministic and consistent
  - Higher values (0.7-2.0): More random and creative
  - Ignored by providers whose current models do not accept it (Anthropic)
- `provider` (Symbol or String, optional): LLM provider (default: `:openai`)
  - Supported: `:openai`, `:anthropic`, `:gemini`, `:groq`, `:spacexai`
- `model` (String, optional): Model ID override (default: the provider's default model)

**Returns:** `VibeSort::Client` instance

**Raises:**

- `ArgumentError`: If api_key is nil or empty, or the provider is unknown

**Example:**

```ruby
# Basic initialization (OpenAI, default provider)
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])

# Anthropic Claude
client = VibeSort::Client.new(provider: :anthropic, api_key: ENV['ANTHROPIC_API_KEY'])

# Google Gemini with a custom model
client = VibeSort::Client.new(provider: :gemini, api_key: ENV['GEMINI_API_KEY'], model: 'gemini-2.5-pro')

# With custom temperature
client = VibeSort::Client.new(
  api_key: ENV['OPENAI_API_KEY'],
  temperature: 0.2
)
```

### Instance Methods

#### `sort(array)`

Sorts an array of numbers and/or strings using the configured provider's API.

**Parameters:**

- `array` (Array, required): Array of numbers and/or strings to sort

**Returns:** Hash with the following keys:

- `:success` (Boolean): `true` if sorting succeeded, `false` otherwise
- `:sorted_array` (Array): The sorted array (empty on failure)
- `:error` (String): Error message (only present when `success` is `false`)

**Example:**

```ruby
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])

# Successful sort with numbers
result = client.sort([5, 2, 8, 1, 9])
# => { success: true, sorted_array: [1, 2, 5, 8, 9] }

# Successful sort with strings
result = client.sort(["banana", "Apple", "cherry"])
# => { success: true, sorted_array: ["Apple", "banana", "cherry"] }

# Successful sort with mixed types
result = client.sort([42, "hello", 8, "world"])
# => { success: true, sorted_array: [8, 42, "hello", "world"] }

# Invalid input (unsupported type)
result = client.sort([1, :symbol, 3])
# => { success: false, sorted_array: [], error: "Input must be an array of numbers or strings" }

# Empty array
result = client.sort([])
# => { success: false, sorted_array: [], error: "Input must be an array of numbers or strings" }
```

**Supported Types:**

- Integers: `1, 2, 3, -5, 1000`
- Floats: `1.5, 3.14, -2.7`
- Strings: `"hello", "world", "Apple"`
- Mixed: `[1, 2.5, "hello", 3, "world"]`

**Sorting Rules:**

- Numbers are sorted in ascending numerical order
- Strings are sorted in ascending alphabetical order (case-sensitive)
- In mixed arrays, numbers come before strings

---

## VibeSort::Configuration

Configuration object for VibeSort. Usually not used directly by end users.

### Class Methods

#### `new(api_key:, temperature: 0.0, provider: :openai, model: nil)`

Creates a new configuration object.

**Parameters:**

- `api_key` (String, required): API key for the selected provider
- `temperature` (Float, optional): Model temperature (default: 0.0)
- `provider` (Symbol or String, optional): `:openai` (default), `:anthropic`, `:gemini`, `:groq`, or `:spacexai`
- `model` (String, optional): Model ID override (nil uses the provider's default)

**Raises:**

- `ArgumentError`: If api_key is nil or empty, or the provider is unknown

**Example:**

```ruby
config = VibeSort::Configuration.new(
  api_key: "sk-...",
  provider: :anthropic,
  model: "claude-haiku-4-5"
)
```

### Instance Attributes

#### `api_key`

Returns the configured API key (read-only).

**Returns:** String

#### `temperature`

Returns the configured temperature setting (read-only).

**Returns:** Float

#### `provider`

Returns the configured provider (read-only).

**Returns:** Symbol

#### `model`

Returns the configured model override, or nil when using the provider default (read-only).

**Returns:** String or nil

---

## VibeSort::Sorter

Internal class that dispatches the sorting operation to the configured provider adapter. Not intended for direct use.

### Class Methods

#### `new(config)`

Creates a new sorter instance.

**Parameters:**

- `config` (VibeSort::Configuration): Configuration object

### Instance Methods

#### `perform(array)`

Performs the sorting operation via the configured provider's API.

**Parameters:**

- `array` (Array): Array of numbers and/or strings to sort

**Returns:** Hash with `:success`, `:sorted_array`, and optional `:error` keys

**Raises:**

- `VibeSort::ApiError`: On API failures or invalid responses

### Constants

#### `PROVIDER_CLASSES`

Maps provider symbols to adapter classes.

**Value:** `{ openai:, anthropic:, gemini:, groq:, spacexai: }`

---

## VibeSort::Providers

Internal provider adapters. `Providers::Base` holds the shared prompt, Faraday HTTP plumbing, and response validation; each subclass maps one provider's request/response wire format.

| Adapter | Endpoint | `DEFAULT_MODEL` |
|---|---|---|
| `Providers::OpenAI` | `https://api.openai.com/v1/chat/completions` | `gpt-4o-mini` |
| `Providers::Anthropic` | `https://api.anthropic.com/v1/messages` | `claude-opus-4-8` |
| `Providers::Gemini` | `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent` | `gemini-2.5-flash` |
| `Providers::Groq` | `https://api.groq.com/openai/v1/chat/completions` | `llama-3.3-70b-versatile` |
| `Providers::SpaceXAI` | `https://api.x.ai/v1/chat/completions` | `grok-4` |

Notes:

- The Anthropic adapter uses structured outputs (JSON schema) and does not send `temperature` (rejected by current Claude models)
- The Groq and SpaceXAI adapters subclass `Providers::OpenAI` (OpenAI-compatible APIs)

---

## VibeSort::ApiError

Custom exception class for API-related errors.

### Class Methods

#### `new(message, response = nil)`

Creates a new API error.

**Parameters:**

- `message` (String, required): Error message
- `response` (Faraday::Response, optional): HTTP response object

**Example:**

```ruby
raise VibeSort::ApiError.new("Invalid API key", response)
```

### Instance Attributes

#### `message`

Returns the error message.

**Returns:** String

#### `response`

Returns the HTTP response object (if available).

**Returns:** Faraday::Response or nil

---

## Response Hash Format

All sorting operations return a consistent hash structure:

### Success Response

```ruby
{
  success: true,
  sorted_array: [1, 2, 3, 4, 5]
}
```

**Keys:**

- `success` (Boolean): Always `true` for successful operations
- `sorted_array` (Array): The sorted array in ascending order (numbers before strings)

### Error Response

```ruby
{
  success: false,
  sorted_array: [],
  error: "Error message here"
}
```

**Keys:**

- `success` (Boolean): Always `false` for failed operations
- `sorted_array` (Array): Always empty on failure
- `error` (String): Human-readable error message

---

## Error Messages

### Input Validation Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| "Input must be an array of numbers or strings" | Input is not an array | Pass an array |
| "Input must be an array of numbers or strings" | Array is empty | Pass non-empty array |
| "Input must be an array of numbers or strings" | Array contains unsupported types (symbols, objects, etc.) | Use only numbers and strings |

### API Errors

The `{Provider}` prefix names the configured provider (OpenAI, Anthropic, Gemini, Groq, or SpaceXAI):

| Error Message Pattern | Cause | Solution |
|----------------------|-------|----------|
| "{Provider} API error: Invalid API key" | Invalid or missing API key | Check API key |
| "{Provider} API error: Rate limit exceeded" | Too many requests | Wait and retry |
| "{Provider} API error: HTTP {status}" | HTTP error | Check API status |

### Response Parsing Errors

| Error Message Pattern | Cause | Solution |
|----------------------|-------|----------|
| "Failed to parse JSON response: ..." | Malformed JSON | Retry request |
| "Response does not contain a valid 'sorted_array'" | Missing key | Report bug |
| "Sorted array contains invalid values (must be numbers or strings)" | Invalid response | Report bug |
| "Invalid response structure" | Unexpected format | Report bug |

### Unexpected Errors

| Error Message Pattern | Cause | Solution |
|----------------------|-------|----------|
| "Unexpected error: ..." | Network issues, bugs, etc. | Check logs, retry |

---

## Usage Examples

### Basic Usage

```ruby
require 'vibe_sort'

client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])
result = client.sort([5, 2, 8, 1, 9])

if result[:success]
  puts result[:sorted_array]
  # => [1, 2, 5, 8, 9]
end
```

### Error Handling

```ruby
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])
result = client.sort([5, :symbol, 8])

unless result[:success]
  puts "Error: #{result[:error]}"
  # => Error: Input must be an array of numbers or strings
end
```

### With Custom Temperature

```ruby
# More deterministic (recommended)
client = VibeSort::Client.new(
  api_key: ENV['OPENAI_API_KEY'],
  temperature: 0.0
)

# More random (not recommended for sorting!)
client = VibeSort::Client.new(
  api_key: ENV['OPENAI_API_KEY'],
  temperature: 1.0
)
```

### Different Number Types

```ruby
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])

# Integers
client.sort([5, 2, 8, 1, 9])
# => { success: true, sorted_array: [1, 2, 5, 8, 9] }

# Floats
client.sort([3.14, 1.5, 2.7])
# => { success: true, sorted_array: [1.5, 2.7, 3.14] }

# Mixed numbers
client.sort([5, 2.5, 8, 1.2, 9])
# => { success: true, sorted_array: [1.2, 2.5, 5, 8, 9] }

# Negative numbers
client.sort([-5, 2, -8, 1, 9])
# => { success: true, sorted_array: [-8, -5, 1, 2, 9] }

# Strings
client.sort(["banana", "Apple", "cherry"])
# => { success: true, sorted_array: ["Apple", "banana", "cherry"] }

# Mixed types (numbers before strings)
client.sort([42, "hello", 8, "world", 15.5])
# => { success: true, sorted_array: [8, 15.5, 42, "hello", "world"] }
```

### Conditional Logic

```ruby
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])
numbers = gets.chomp.split.map(&:to_i)

result = client.sort(numbers)

case result[:success]
when true
  puts "Sorted: #{result[:sorted_array].join(', ')}"
when false
  warn "Failed to sort: #{result[:error]}"
  exit 1
end
```

---

## Thread Safety

VibeSort::Client instances are **not thread-safe**. If you need to sort arrays concurrently:

1. Create separate client instances per thread
2. Use a thread-safe queue for results
3. Consider connection pooling for high-concurrency scenarios

**Example:**

```ruby
api_key = ENV['OPENAI_API_KEY']

threads = 5.times.map do |i|
  Thread.new do
    client = VibeSort::Client.new(api_key: api_key)
    client.sort([rand(100), rand(100), rand(100)])
  end
end

results = threads.map(&:value)
```

---

## Environment Variables

Set the API key for whichever provider you use:

```bash
export OPENAI_API_KEY='sk-your-key-here'      # provider: :openai (default)
export ANTHROPIC_API_KEY='your-key-here'      # provider: :anthropic
export GEMINI_API_KEY='your-key-here'         # provider: :gemini
export GROQ_API_KEY='your-key-here'           # provider: :groq
export XAI_API_KEY='your-key-here'            # provider: :spacexai
```

**Usage:**

```ruby
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])
```

---

## Version

Current version: `0.3.0`

```ruby
VibeSort::VERSION
# => "0.3.0"
```
