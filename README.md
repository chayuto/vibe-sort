# 🌀 VibeSort

> **AI-powered array sorting using OpenAI's GPT models**

VibeSort is a proof-of-concept Ruby gem that demonstrates sorting number arrays by leveraging the OpenAI Chat Completions API. Instead of using traditional sorting algorithms, it asks GPT to do the work!

[![Gem Version](https://badge.fury.io/rb/vibe-sort.svg)](https://badge.fury.io/rb/vibe-sort)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## ⚠️ Disclaimer

This is a **proof-of-concept** and educational project. It is not intended for production use. Traditional sorting algorithms are far more efficient, reliable, and cost-effective. Use this gem to explore AI capabilities, not to sort arrays in real applications!

## ✨ Features

- 🤖 **AI-Powered Sorting**: Uses OpenAI's GPT models to sort arrays
- 🎯 **Simple Interface**: Clean, intuitive API with a single `sort` method
- 🔧 **Configurable**: Supports custom temperature settings for model behavior
- 🛡️ **Error Handling**: Comprehensive error handling with clear error messages
- 📊 **Structured Output**: Uses JSON mode for reliable, parsable responses
- 🔍 **Type Validation**: Validates input and output to ensure data integrity
- 📝 **Mixed-Type Support**: Sorts arrays containing integers, floats, and strings

## ✅ Requirements

- Ruby **3.0** or newer (MRI)
- Bundler **2.0+**
- An OpenAI API key with access to the Chat Completions API
- Internet connectivity (each sort performs a remote API call)

## 📦 Installation

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

## ⚡ Quick Start

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

## 🚀 Usage

### Basic Usage

```ruby
require 'vibe_sort'

# Initialize the client with your OpenAI API key
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])

# Sort an array of numbers
numbers = [34, 1, 99, 15, 8]
result = client.sort(numbers)

if result[:success]
  puts "✅ Vibe Sort successful!"
  puts "Original: #{numbers}"
  puts "Sorted: #{result[:sorted_array]}"
  # Output: [1, 8, 15, 34, 99]
else
  puts "❌ Vibe Sort failed: #{result[:error]}"
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

### Advanced Configuration

You can customize the model's behavior using the `temperature` parameter:

```ruby
# Lower temperature (0.0) = more deterministic, consistent results
client = VibeSort::Client.new(
  api_key: ENV['OPENAI_API_KEY'],
  temperature: 0.0
)

# Higher temperature = more creative/random (not recommended for sorting!)
creative_client = VibeSort::Client.new(
  api_key: ENV['OPENAI_API_KEY'],
  temperature: 0.5
)
```

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

## 🏗️ Architecture

VibeSort follows a clean, modular architecture:

- **`VibeSort::Client`**: Public interface for users
- **`VibeSort::Configuration`**: Manages API key and settings
- **`VibeSort::Sorter`**: Handles OpenAI API communication via Faraday
- **`VibeSort::ApiError`**: Custom exception for API-related errors

See the [Architecture Documentation](docs/architecture.md) for more details.

## 📚 Documentation

- [Architecture Overview](docs/architecture.md)
- [API Reference](docs/api_reference.md)
- [Development Guide](docs/development.md)

## 🧪 Development

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

## 🤔 Why Does This Exist?

This gem was created as an educational exercise to:

1. Explore the capabilities and limitations of LLMs for computational tasks
2. Demonstrate how to integrate OpenAI's API into Ruby applications
3. Provide a template for building Ruby gems with external API dependencies
4. Spark conversations about appropriate use cases for AI

**Please note**: This is intentionally inefficient and expensive compared to traditional sorting algorithms. It's a conversation starter, not a production solution!

## ⚡ Performance Considerations

- **Latency**: Each sort requires an API call (typically 1-3 seconds)
- **Cost**: OpenAI API usage is metered and costs money
- **Reliability**: Depends on API availability and internet connection
- **Accuracy**: Generally accurate, but not guaranteed (unlike algorithmic sorting)
- **Scale**: Not suitable for large arrays or high-frequency sorting

Traditional sorting (e.g., Ruby's `Array#sort`) is:

- ⚡ **10,000x faster** (microseconds vs seconds)
- 💰 **Free** (no API costs)
- 🎯 **100% reliable** (deterministic algorithm)
- 📈 **Scalable** (handles millions of elements)

## 🔑 Environment Variables

Set your OpenAI API key as an environment variable:

```bash
export OPENAI_API_KEY='your-api-key-here'
```

Or use a `.env` file with the `dotenv` gem:

```ruby
# Gemfile
gem 'dotenv'

# In your code
require 'dotenv/load'
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])
```

## 📄 License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## 🙏 Acknowledgments

- Built with [Faraday](https://lostisland.github.io/faraday/) for HTTP requests
- Powered by [OpenAI](https://openai.com/) GPT models
- Inspired by the absurdity and creativity of the AI era

---

**Remember**: With great AI power comes great responsibility (and API bills). Sort wisely! 🧙‍♂️
