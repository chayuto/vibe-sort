# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-10-16

### Added

- **Mixed-Type Array Support**: Arrays can now contain integers, floats, AND strings
- String sorting capability with case-sensitive alphabetical ordering
- Mixed-type sorting with standard rules (numbers before strings)
- Enhanced AI prompt to handle multiple data types intelligently
- Updated examples in README and documentation for string and mixed-type arrays

### Changed

- Input validation now accepts `Numeric` or `String` types (previously `Numeric` only)
- Error message updated to "Input must be an array of numbers or strings"
- System prompt generalized to handle diverse array compositions
- Output validation updated to accept numbers and strings
- API documentation updated to reflect new capabilities

### Documentation

- Added string sorting examples to README
- Added mixed-type array examples to README
- Updated API reference with new sorting rules
- Added sorting behavior section explaining number/string ordering
- Updated error messages in documentation

### Technical Details

- `VibeSort::Client#valid_input?` now checks for `Numeric || String`
- `VibeSort::Sorter#build_payload` uses generalized AI instructions
- `VibeSort::Sorter#validate_sorted_array!` accepts both numeric and string values
- All method signatures and documentation updated accordingly

### Sorting Rules

- **Numbers only**: Ascending numerical order
- **Strings only**: Ascending alphabetical order (case-sensitive)
- **Mixed arrays**: Numbers sorted first, then strings, each group sorted within itself

## [0.1.0] - 2025-10-16

### Added

- Initial release of VibeSort gem
- Core functionality: AI-powered array sorting using OpenAI API
- `VibeSort::Client` - Main public interface for sorting arrays
- `VibeSort::Configuration` - Configuration management for API key and temperature
- `VibeSort::Sorter` - HTTP client for OpenAI API communication via Faraday
- `VibeSort::ApiError` - Custom exception class for API errors
- Comprehensive error handling with detailed error messages
- Input validation for array types and numeric values
- JSON mode support for reliable, structured API responses
- Temperature configuration for controlling model behavior
- Full test suite with RSpec
- Complete documentation:
  - README with usage examples and installation instructions
  - Architecture documentation (`docs/architecture.md`)
  - API reference (`docs/api_reference.md`)
  - Development guide (`docs/development.md`)
- Runtime dependencies:
  - `faraday` (~> 2.0) for HTTP requests
  - `faraday-json` (~> 1.0) for JSON middleware
- Development dependencies:
  - `rspec` (~> 3.0) for testing
  - `pry` (~> 0.14) for debugging

### Features

- Sort arrays of integers, floats, or mixed numeric types
- Configurable model temperature (default: 0.0 for deterministic results)
- Consistent return format with success flag, sorted array, and error messages
- Support for positive and negative numbers
- Graceful error handling for invalid inputs and API failures
- Thread-safe configuration per client instance

### Documentation

- Comprehensive README with examples and disclaimers
- Architecture overview with component diagrams
- Complete API reference for all public methods
- Development guide with setup instructions and best practices
- Code examples for common use cases
- Performance considerations and cost analysis
- Security best practices for API key management

### Notes

- This is a proof-of-concept gem for educational purposes
- Not recommended for production use
- Traditional sorting algorithms are faster, cheaper, and more reliable
- Requires OpenAI API key and internet connection
- Each sort operation incurs API costs (~$0.001-0.002 per request)
