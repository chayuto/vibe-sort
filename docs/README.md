# VibeSort Documentation

Welcome to the VibeSort documentation! This directory contains comprehensive guides for using, understanding, and contributing to the VibeSort gem.

## 📚 Documentation Overview

### [Architecture Overview](architecture.md)

**Target Audience:** Developers who want to understand how VibeSort works internally

**Contents:**
- System design and component architecture
- Class responsibilities and interactions
- Request flow from user to OpenAI API
- Error handling strategies
- Design decisions and rationale
- Future enhancement ideas

**When to read:** Before contributing code or when you need to understand the internal structure.

---

### [API Reference](api_reference.md)

**Target Audience:** Developers using VibeSort in their applications

**Contents:**
- Complete API documentation for all public classes and methods
- Parameter descriptions and return values
- Usage examples for each method
- Error messages and their meanings
- Response format specifications
- Thread safety considerations

**When to read:** When integrating VibeSort into your project or looking up specific method signatures.

---

### [Development Guide](development.md)

**Target Audience:** Contributors and maintainers

**Contents:**
- Project setup instructions
- Running tests and debugging
- Code style guidelines
- Release process
- Common development tasks
- Troubleshooting tips

**When to read:** Before contributing to the project or when setting up your development environment.

---

## 🚀 Quick Links

### For Users

- **Getting Started:** See the main [README](../README.md)
- **Installation:** [README - Installation](../README.md#-installation)
- **Usage Examples:** [README - Usage](../README.md#-usage) or [API Reference](api_reference.md#usage-examples)
- **Error Handling:** [API Reference - Error Messages](api_reference.md#error-messages)

### For Contributors

- **Setup:** [Development Guide - Getting Started](development.md#getting-started)
- **Running Tests:** [Development Guide - Running Tests](development.md#running-tests)
- **Code Style:** [Development Guide - Code Style](development.md#code-style)
- **Pull Requests:** [Development Guide - Best Practices](development.md#best-practices)

### For Maintainers

- **Architecture:** [Architecture Overview](architecture.md)
- **Release Process:** [Development Guide - Release Process](development.md#release-process)
- **Design Decisions:** [Architecture - Design Decisions](architecture.md#design-decisions)

---

## 📖 Reading Guide

### I want to use VibeSort in my project

1. Start with the [README](../README.md) for a quick overview
2. Check the [API Reference](api_reference.md) for detailed method documentation
3. Review usage examples in both documents
4. Understand error handling from the [API Reference](api_reference.md#error-messages)

### I want to contribute to VibeSort

1. Read the [Development Guide](development.md) for setup instructions
2. Review the [Architecture Overview](architecture.md) to understand the codebase
3. Follow the code style guidelines in the [Development Guide](development.md#code-style)
4. Write tests (see [Development Guide - Writing Tests](development.md#writing-tests))

### I want to understand how VibeSort works

1. Start with the [Architecture Overview](architecture.md)
2. Review the [Request Flow](architecture.md#request-flow) section
3. Check the [Design Decisions](architecture.md#design-decisions) section
4. Look at the source code in `lib/vibe_sort/`

### I encountered an error

1. Check [API Reference - Error Messages](api_reference.md#error-messages)
2. Review [Development Guide - Troubleshooting](development.md#troubleshooting)
3. Open an issue on GitHub if the error persists

---

## 🏗️ Architecture at a Glance

```
User Application
      ↓
VibeSort::Client (validates input, handles errors)
      ↓
VibeSort::Configuration (stores API key, settings)
      ↓
VibeSort::Sorter (communicates with OpenAI)
      ↓
OpenAI API (GPT model processes request)
      ↓
Sorted Array (returned to user)
```

---

## 📝 Example Usage

```ruby
require 'vibe_sort'

# Initialize client
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])

# Sort an array
result = client.sort([34, 1, 99, 15, 8])

if result[:success]
  puts result[:sorted_array]
  # => [1, 8, 15, 34, 99]
else
  puts result[:error]
end
```

For more examples, see the [README](../README.md) or [API Reference](api_reference.md).

---

## 🔧 Key Concepts

### Configuration

VibeSort requires an OpenAI API key and optionally accepts a temperature parameter:

- **API Key:** Your OpenAI authentication token
- **Temperature:** Controls model randomness (0.0 = deterministic, 2.0 = creative)

### Response Format

All operations return a consistent hash:

```ruby
{
  success: true/false,
  sorted_array: [...],
  error: "..." # only on failure
}
```

### Error Handling

VibeSort never raises exceptions to user code. All errors are caught and returned in the response hash.

---

## 🤝 Contributing

We welcome contributions! Please see:

- [Development Guide](development.md) for technical setup
- [GitHub Issues](https://github.com/chayut/vibe-sort/issues) for bugs and features
- [Pull Request Template](https://github.com/chayut/vibe-sort/pulls) for submitting changes

---

## 📞 Support

- 🐛 [Report a Bug](https://github.com/chayut/vibe-sort/issues/new?labels=bug)
- 💡 [Request a Feature](https://github.com/chayut/vibe-sort/issues/new?labels=enhancement)
- 📖 [Read the Docs](README.md)
- 💬 [Discussions](https://github.com/chayut/vibe-sort/discussions)

---

## 📜 License

VibeSort is released under the [MIT License](../LICENSE.txt).

---

## 🙏 Acknowledgments

- Built with [Faraday](https://lostisland.github.io/faraday/)
- Powered by [OpenAI](https://openai.com/)
- Inspired by the possibilities of AI

---

**Happy Sorting! 🌀**
