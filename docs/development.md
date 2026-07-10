# Development Guide

## Getting Started

### Prerequisites

- Ruby >= 3.0.0
- Bundler
- Git
- OpenAI API key (for integration tests)

### Initial Setup

1. **Clone the repository**

```bash
git clone https://github.com/chayut/vibe-sort.git
cd vibe-sort
```

2. **Install dependencies**

```bash
bundle install
```

3. **Set up environment variables**

Create a `.env` file (not committed to git):

```bash
echo "OPENAI_API_KEY=your-api-key-here" > .env
```

Or export it in your shell:

```bash
export OPENAI_API_KEY='sk-your-key-here'
```

4. **Run the console**

```bash
bin/console
```

This starts an IRB session with the gem loaded:

```ruby
irb(main):001:0> client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])
irb(main):002:0> client.sort([5, 2, 8, 1, 9])
# => {:success=>true, :sorted_array=>[1, 2, 5, 8, 9]}
```

## Project Structure

```
vibe-sort/
├── lib/
│   ├── vibe_sort.rb              # Main entry point
│   └── vibe_sort/
│       ├── client.rb             # Public API
│       ├── configuration.rb      # Config object
│       ├── error.rb              # Custom exceptions
│       ├── sorter.rb             # API communication
│       └── version.rb            # Version constant
├── spec/
│   ├── spec_helper.rb            # RSpec configuration
│   └── vibe_sort/
│       ├── client_spec.rb        # Client tests
│       ├── configuration_spec.rb # Configuration tests
│       ├── sorter_spec.rb        # Sorter tests
│       └── integration_spec.rb   # End-to-end tests
├── docs/
│   ├── architecture.md           # Architecture overview
│   ├── api_reference.md          # API documentation
│   └── development.md            # This file
├── bin/
│   ├── console                   # Interactive console
│   └── setup                     # Setup script
├── Gemfile                       # Dependencies
├── Rakefile                      # Rake tasks
├── vibe-sort.gemspec             # Gem specification
├── README.md                     # User documentation
├── CHANGELOG.md                  # Version history
└── LICENSE.txt                   # MIT License
```

## Running Tests

### All Tests

```bash
bundle exec rspec
```

### With Coverage

```bash
bundle exec rspec --format documentation
```

### Specific Test File

```bash
bundle exec rspec spec/vibe_sort/client_spec.rb
```

### Specific Test

```bash
bundle exec rspec spec/vibe_sort/client_spec.rb:23
```

### Watch Mode (with guard)

```bash
bundle exec guard
```

## Writing Tests

### Unit Tests

Mock external API calls using WebMock or VCR:

```ruby
# spec/vibe_sort/sorter_spec.rb
require 'spec_helper'

RSpec.describe VibeSort::Sorter do
  let(:config) { VibeSort::Configuration.new(api_key: 'test-key') }
  let(:sorter) { described_class.new(config) }

  describe '#perform' do
    it 'sorts the array via API' do
      stub_request(:post, VibeSort::Sorter::OPENAI_API_URL)
        .with(
          headers: { 'Authorization' => 'Bearer test-key' },
          body: hash_including(model: 'gpt-3.5-turbo-1106')
        )
        .to_return(
          status: 200,
          body: {
            choices: [{
              message: {
                content: '{"sorted_array": [1, 2, 3]}'
              }
            }]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      result = sorter.perform([3, 1, 2])
      
      expect(result[:success]).to be true
      expect(result[:sorted_array]).to eq([1, 2, 3])
    end
  end
end
```

### Integration Tests

Test with real API (use test API key):

```ruby
# spec/vibe_sort/integration_spec.rb
require 'spec_helper'

RSpec.describe 'Integration Tests', :integration do
  let(:api_key) { ENV['OPENAI_API_KEY'] }
  let(:client) { VibeSort::Client.new(api_key: api_key) }

  before do
    skip 'No API key provided' unless api_key
  end

  it 'sorts an array end-to-end' do
    result = client.sort([5, 2, 8, 1, 9])
    
    expect(result[:success]).to be true
    expect(result[:sorted_array]).to eq([1, 2, 5, 8, 9])
  end
end
```

Run integration tests separately:

```bash
bundle exec rspec --tag integration
```

## Code Style

### Linting

Use RuboCop for code style:

```bash
bundle exec rubocop
```

Auto-fix issues:

```bash
bundle exec rubocop -a
```

### Style Guidelines

- Use 2 spaces for indentation
- Keep lines under 120 characters
- Use snake_case for methods and variables
- Use CamelCase for classes and modules
- Add comments for complex logic
- Write descriptive method and variable names

### Example

```ruby
# Good
def build_payload(array)
  {
    model: DEFAULT_MODEL,
    temperature: config.temperature,
    messages: build_messages(array)
  }
end

# Bad
def bp(a)
  { m: M, t: c.t, msgs: bm(a) }
end
```

## Debugging

### Using Pry

Add `binding.pry` anywhere in the code:

```ruby
def sort(array)
  binding.pry  # Execution will stop here
  
  unless valid_input?(array)
    return { success: false, sorted_array: [], error: "Invalid input" }
  end
  
  # ...
end
```

Then run your code:

```bash
bundle exec rspec spec/vibe_sort/client_spec.rb
```

### Logging HTTP Requests

Enable Faraday logging:

```ruby
# lib/vibe_sort/sorter.rb
def connection
  @connection ||= Faraday.new(url: OPENAI_API_URL) do |f|
    f.request :json
    f.response :json
    f.response :logger  # Add this line
    f.adapter Faraday.default_adapter
  end
end
```

## Building the Gem

### Local Build

```bash
gem build vibe-sort.gemspec
```

This creates `vibe-sort-0.1.0.gem`.

### Local Install

```bash
gem install ./vibe-sort-0.1.0.gem
```

Or use rake:

```bash
bundle exec rake install
```

### Test Local Gem

```bash
irb
```

```ruby
require 'vibe_sort'
client = VibeSort::Client.new(api_key: ENV['OPENAI_API_KEY'])
client.sort([5, 2, 8])
```

## Release Process

### 1. Update Version

Edit `lib/vibe_sort/version.rb`:

```ruby
module VibeSort
  VERSION = "0.2.0"
end
```

### 2. Update CHANGELOG

Add release notes to `CHANGELOG.md`:

```markdown
## [0.2.0] - 2025-10-17

### Added
- New feature X
- New feature Y

### Fixed
- Bug fix Z
```

### 3. Commit Changes

```bash
git add -A
git commit -m "Bump version to 0.2.0"
git tag v0.2.0
git push origin main --tags
```

### 4. Build and Release

```bash
bundle exec rake release
```

This will:
- Build the gem
- Create a git tag
- Push to RubyGems.org (if configured)

## Documentation

### Generating RDoc

```bash
bundle exec rake rdoc
```

Output: `doc/` directory

### Generating YARD Docs

Add `yard` to Gemfile:

```ruby
gem 'yard', group: :development
```

Then run:

```bash
bundle exec yard doc
```

Output: `doc/` directory

View docs:

```bash
bundle exec yard server
```

Visit: http://localhost:8808

## Common Tasks

### Add a New Feature

1. Write a failing test
2. Implement the feature
3. Make the test pass
4. Refactor if needed
5. Update documentation
6. Commit changes

### Fix a Bug

1. Write a test that reproduces the bug
2. Fix the bug
3. Ensure all tests pass
4. Update CHANGELOG
5. Commit changes

### Add a Dependency

1. Add to `vibe-sort.gemspec`:

```ruby
spec.add_dependency "new-gem", "~> 1.0"
```

2. Run `bundle install`
3. Update documentation
4. Commit changes

### Remove a Dependency

1. Remove from `vibe-sort.gemspec`
2. Remove all usage from code
3. Run `bundle install`
4. Run tests to ensure nothing breaks
5. Update documentation
6. Commit changes

## Troubleshooting

### Tests Failing

**Check API key:**

```bash
echo $OPENAI_API_KEY
```

**Check dependencies:**

```bash
bundle check
bundle install
```

**Check Ruby version:**

```bash
ruby -v
```

### Gem Won't Build

**Check gemspec:**

```bash
gem build vibe-sort.gemspec
```

Look for errors in output.

**Check file permissions:**

```bash
ls -la
```

### API Errors

**Test API key manually:**

```bash
curl https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Best Practices

### 1. Test Coverage

Aim for 100% coverage:

```bash
bundle exec rspec --format documentation
```

### 2. Error Handling

Always handle errors gracefully:

```ruby
def sort(array)
  # Validate input
  return error_hash("Invalid input") unless valid_input?(array)
  
  # Perform operation
  sorter.perform(array)
rescue ApiError => e
  error_hash(e.message)
rescue StandardError => e
  error_hash("Unexpected error: #{e.message}")
end
```

### 3. Documentation

Document all public methods:

```ruby
# Sort an array of numbers using OpenAI API
#
# @param array [Array<Numeric>] Array of numbers to sort
# @return [Hash] Result hash with :success, :sorted_array, :error keys
#
# @example
# client.sort([5, 2, 8])
# # => { success: true, sorted_array: [2, 5, 8] }
def sort(array)
  # ...
end
```

### 4. Git Workflow

Use meaningful commit messages:

```bash
git commit -m "feat: Add support for custom models"
git commit -m "fix: Handle empty API responses"
git commit -m "docs: Update API reference"
```

### 5. Code Reviews

Before submitting a PR:

- Run all tests
- Check code style
- Update documentation
- Add CHANGELOG entry
- Write a clear PR description

## Resources

- [Ruby Style Guide](https://rubystyle.guide/)
- [RSpec Best Practices](https://www.betterspecs.org/)
- [Semantic Versioning](https://semver.org/)
- [OpenAI API Docs](https://platform.openai.com/docs/)
- [Faraday Documentation](https://lostisland.github.io/faraday/)

## Getting Help

- Open an issue on GitHub
- Check existing issues and PRs
- Read the documentation
- Ask in the community

Happy coding! 
