# VibeSort

> **AI-powered array sorting using OpenAI, Anthropic Claude, Google Gemini, Groq, SpaceXAI Grok, or OpenRouter**

VibeSort is a proof-of-concept Ruby gem that demonstrates sorting arrays by leveraging LLM APIs. Instead of using traditional sorting algorithms, it asks an AI model to do the work. Supports the OpenAI Chat Completions API, the Anthropic Messages API, the Google Gemini API, and the OpenAI-compatible Groq, SpaceXAI (xAI), and OpenRouter APIs, with zero dependencies beyond Faraday.

[![Gem Version](https://badge.fury.io/rb/vibe-sort.svg)](https://badge.fury.io/rb/vibe-sort)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Disclaimer

This is a **proof-of-concept** and educational project. It is not intended for production use. Traditional sorting algorithms are far more efficient, reliable, and cost-effective. Use this gem to explore AI capabilities, not to sort arrays in real applications.

## Features

- **AI-Powered Sorting**: Uses OpenAI, Anthropic Claude, Google Gemini, Groq, SpaceXAI Grok, or OpenRouter models to sort arrays
- **Multi-Provider**: Switch providers with a single `provider:` option, no extra dependencies
- **Key Format Detection**: Omit `provider:` and VibeSort infers it from your API key's prefix
- **Simple Interface**: Clean, intuitive API with a single `sort` method
- **Configurable**: Custom model, temperature, and an `extra_params:` escape hatch for any provider-native request parameter
- **Error Handling**: Comprehensive error handling with clear error messages
- **Structured Output**: Uses JSON mode for reliable, parsable responses
- **Type Validation**: Validates input and output to ensure data integrity
- **Mixed-Type Support**: Sorts arrays containing integers, floats, and strings

## Requirements

- Ruby **3.0** or newer (MRI)
- Bundler **2.0+**
- An API key for at least one supported provider (OpenAI, Anthropic, Google Gemini, Groq, SpaceXAI, or OpenRouter)
- Internet connectivity (each sort performs a remote API call)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vibe-sort'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install vibe-sort
```

## Quick Start

```bash
export OPENAI_API_KEY="your-openai-api-key"
bundle exec ruby -e "require 'vibe_sort'; client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY']); puts client.sort([34, 1, 'Apple', 8.5])"
```

Or fire up the bundled console for interactive experimentation:

```bash
OPENAI_API_KEY=your-openai-api-key bundle exec bin/console
```

```ruby
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])
client.sort([34, 1, 'Apple', 8.5])
# => { success: true, sorted_array: [1, 8.5, 34, "Apple"] }
```

## Usage

### Basic Usage

```ruby
require 'vibe_sort'

# Initialize the client with your OpenAI API key
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])

# Sort an array of numbers
numbers = [34, 1, 99, 15, 8]
result = client.sort(numbers)

if result[:success]
  puts "Vibe Sort successful!"
  puts "Original: #{numbers}"
  puts "Sorted: #{result[:sorted_array]}"
  # Output: [1, 8, 15, 34, 99]
else
  puts "Vibe Sort failed: #{result[:error]}"
end
```

### Sorting Strings

```ruby
# Sort an array of strings (case-sensitive)
words = ["banana", "Apple", "cherry", "date"]
result = client.sort(words)

if result[:success]
  puts "Sorted strings: #{result[:sorted_array]}"
  # Output: ["Apple", "banana", "cherry", "date"]
end
```

### Sorting Mixed Types

```ruby
# Sort arrays containing both numbers and strings
mixed_items = [42, "hello", 8, "world", 15.5, "Apple"]
result = client.sort(mixed_items)

if result[:success]
  puts "Sorted mixed array: #{result[:sorted_array]}"
  # Output: [8, 15.5, 42, "Apple", "hello", "world"]
  # Note: Numbers come before strings in the sorted output
end
```

### Choosing a Provider

Any supported provider can be selected with the `provider:` option:

```ruby
# OpenAI
client = VibeSort::Client.new(provider: :openai, api_key: ENV['OPENAI_API_KEY'])

# Anthropic Claude
client = VibeSort::Client.new(provider: :anthropic, api_key: ENV['ANTHROPIC_API_KEY'])

# Google Gemini
client = VibeSort::Client.new(provider: :gemini, api_key: ENV['GEMINI_API_KEY'])

# Groq (fast open-model inference)
client = VibeSort::Client.new(provider: :groq, api_key: ENV['GROQ_API_KEY'])

# SpaceXAI (formerly xAI) Grok
client = VibeSort::Client.new(provider: :spacexai, api_key: ENV['XAI_API_KEY'])

# OpenRouter (hundreds of models behind one API)
client = VibeSort::Client.new(provider: :openrouter, api_key: ENV['OPENROUTER_API_KEY'])
```

| Provider | API | Default model | Override with `model:` |
|---|---|---|---|
| `:openai` | Chat Completions | `gpt-4o-mini` | any chat model |
| `:anthropic` | Messages | `claude-opus-4-8` | e.g. `claude-haiku-4-5` for cheaper sorts |
| `:gemini` | generateContent | `gemini-2.5-flash` | e.g. `gemini-2.5-pro` |
| `:groq` | Chat Completions (OpenAI-compatible) | `llama-3.3-70b-versatile` | any Groq-hosted model |
| `:spacexai` | Chat Completions (OpenAI-compatible) | `grok-4` | e.g. `grok-4.5` |
| `:openrouter` | Chat Completions (OpenAI-compatible) | `openai/gpt-4o-mini` | any OpenRouter model ID |

> **Groq is not Grok**: Groq is the independent fast-inference company (`api.groq.com`); Grok is SpaceXAI's model (`api.x.ai`). They are unrelated, and VibeSort supports both.

> **OpenRouter JSON mode caveat**: OpenRouter forwards `response_format: { type: "json_object" }` to the underlying model, but only some models honor it. Models that ignore it produce a "Failed to parse JSON response" error. Stick to models that support JSON mode, or use `extra_params:` to adjust the request.

```ruby
# Pick a specific model
client = VibeSort::Client.new(
  provider: :anthropic,
  api_key: ENV['ANTHROPIC_API_KEY'],
  model: 'claude-haiku-4-5'
)
```

### Provider Detection (provider: is optional)

If you omit `provider:`, VibeSort infers it from your API key's prefix:

```ruby
VibeSort::Client.new(api_key: 'sk-ant-...')  # => :anthropic
VibeSort::Client.new(api_key: 'sk-or-...')   # => :openrouter
VibeSort::Client.new(api_key: 'gsk_...')     # => :groq
VibeSort::Client.new(api_key: 'AIza...')     # => :gemini (classic key)
VibeSort::Client.new(api_key: 'AQ....')      # => :gemini (newer key format)
VibeSort::Client.new(api_key: 'xai-...')     # => :spacexai
VibeSort::Client.new(api_key: 'sk-...')      # => :openai
```

Key prefixes are conventions, not contracts, so detection is deliberately soft:

- Unrecognized key formats (proxies, gateways, self-hosted endpoints) default to `:openai` — same behavior as before v0.4.0
- An explicit `provider:` always wins; if it disagrees with the detected format you get a one-line stderr warning, never an error

### Extra Request Parameters

`extra_params:` deep-merges a hash of provider-native parameters into the request payload **last**, so it can add to or override anything VibeSort builds:

```ruby
# Cap completion length (OpenAI/Groq/SpaceXAI/OpenRouter wire format)
client = VibeSort::Client.new(
  api_key: ENV['OPENAI_API_KEY'],
  extra_params: { max_tokens: 200 }
)

# Gemini uses its own parameter names — nested hashes merge recursively
client = VibeSort::Client.new(
  provider: :gemini,
  api_key: ENV['GEMINI_API_KEY'],
  extra_params: { generationConfig: { maxOutputTokens: 256 } }
)

# OpenRouter provider-routing preferences
client = VibeSort::Client.new(
  provider: :openrouter,
  api_key: ENV['OPENROUTER_API_KEY'],
  extra_params: { provider: { sort: 'throughput' } }
)
```

Keys are provider-native and passed through untranslated: `max_tokens` means whatever your provider says it means, and Gemini users write Gemini's camelCase names. Overriding core keys (`response_format`, `temperature`, even `model`) is allowed — it's an escape hatch, use with care.

### Advanced Configuration

You can customize the model's behavior using the `temperature` parameter:

```ruby
# Lower temperature (0.0) = more deterministic, consistent results
client = VibeSort::Client.new(
  api_key: ENV['OPENAI_API_KEY'],
  temperature: 0.0
)

# Higher temperature = more creative/random (not recommended for sorting)
creative_client = VibeSort::Client.new(
  api_key: ENV['OPENAI_API_KEY'],
  temperature: 0.5
)
```

> **Note**: current Anthropic Claude models no longer accept a `temperature` parameter, so it is ignored when `provider: :anthropic` is used.

### Error Handling

VibeSort provides detailed error information:

```ruby
# Invalid input (unsupported types)
result = client.sort([5, :symbol, 12])
puts result[:error]
# => "Input must be an array of numbers or strings"

# Empty array
result = client.sort([])
puts result[:error]
# => "Input must be an array of numbers or strings"

# Invalid API key
bad_client = VibeSort::Client.new(api_key: "invalid-key")
result = bad_client.sort([1, 2, 3])
puts result[:error]
# => "OpenAI API error: Invalid API key"
```

### Return Value Structure

The `sort` method always returns a hash with the following structure:

```ruby
{
  success: true/false,      # Boolean indicating success or failure
  sorted_array: [...],      # Array of sorted elements (empty on failure)
  error: "..."              # Error message (only present on failure)
}
```

### Sorting Behavior

- **Numbers only**: Sorted in ascending numerical order
- **Strings only**: Sorted in ascending alphabetical order (case-sensitive)
- **Mixed types**: Numbers come before strings; each group sorted within itself

## Architecture

VibeSort follows a clean, modular architecture:

- **`VibeSort::Client`**: Public interface for users
- **`VibeSort::Configuration`**: Manages provider, API key, model, and settings
- **`VibeSort::KeyDetector`**: Best-effort provider inference from API key prefixes
- **`VibeSort::Sorter`**: Dispatches to the configured provider adapter
- **`VibeSort::Providers::Base`**: Shared prompt, HTTP plumbing (Faraday), and response validation
- **`VibeSort::Providers::{OpenAI, Anthropic, Gemini, Groq, SpaceXAI, OpenRouter}`**: Provider-specific request/response mapping
- **`VibeSort::ApiError`**: Custom exception for API-related errors

See the [Architecture Documentation](docs/architecture.md) for more details.

## Documentation

- [Architecture Overview](docs/architecture.md)
- [API Reference](docs/api_reference.md)
- [Development Guide](docs/development.md)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run console for experimentation
bin/console
```

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run with coverage
bundle exec rspec --format documentation

# Run specific test file
bundle exec rspec spec/vibe/sort_spec.rb
```

## Why Does This Exist?

This gem was created as an educational exercise to:

1. Explore the capabilities and limitations of LLMs for computational tasks
2. Demonstrate how to integrate LLM APIs into Ruby applications
3. Provide a template for building Ruby gems with external API dependencies
4. Spark conversations about appropriate use cases for AI

**Please note**: This is intentionally inefficient and expensive compared to traditional sorting algorithms. It's a conversation starter, not a production solution.

## Performance Considerations

- **Latency**: Each sort requires an API call (typically 1-3 seconds)
- **Cost**: LLM API usage is metered and costs money
- **Reliability**: Depends on API availability and internet connection
- **Accuracy**: Generally accurate, but not guaranteed (unlike algorithmic sorting)
- **Scale**: Not suitable for large arrays or high-frequency sorting

Traditional sorting (e.g., Ruby's `Array#sort`) is:

- **10,000x faster** (microseconds vs seconds)
- **Free** (no API costs)
- **100% reliable** (deterministic algorithm)
- **Scalable** (handles millions of elements)

## Environment Variables

Set the API key for your chosen provider as an environment variable:

```bash
export OPENAI_API_KEY='your-api-key-here'      # provider: :openai (fallback default)
export ANTHROPIC_API_KEY='your-api-key-here'   # provider: :anthropic
export GEMINI_API_KEY='your-api-key-here'      # provider: :gemini
export GROQ_API_KEY='your-api-key-here'        # provider: :groq
export XAI_API_KEY='your-api-key-here'         # provider: :spacexai
export OPENROUTER_API_KEY='your-api-key-here'  # provider: :openrouter
```

Or use a `.env` file with the `dotenv` gem:

```ruby
# Gemfile
gem 'dotenv'

# In your code
require 'dotenv/load'
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgments

- Built with [Faraday](https://lostisland.github.io/faraday/) for HTTP requests
- Powered by [OpenAI](https://openai.com/), [Anthropic](https://www.anthropic.com/), [Google Gemini](https://ai.google.dev/), [Groq](https://groq.com/), [SpaceXAI](https://x.ai/), and [OpenRouter](https://openrouter.ai/) models
- Inspired by the absurdity and creativity of the AI era

---

**Remember**: With great AI power comes great responsibility (and API bills). Sort wisely.
