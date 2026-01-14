# CF::MCP

CF::MCP is an MCP server providing documentation tools for the [Cute Framework](https://github.com/RandyGaul/cute_framework), a C/C++ 2D game framework.

The MCP server supports two modes of operation:

- **STDIO Mode**: Communicates via standard input and output streams, suitable for integration with CLI tools and desktop applications.
- **HTTP Mode**: Operates as an HTTP server with a web interface at the root and MCP endpoint at `/http`.

## Features

- **Documentation Generation**: Automatically generates documentation for Cute Framework projects by indexing the the header files and extracting the documentation from the comments.
- **Search Functionality**: Provides a search feature to quickly find structs, classes, functions, and other elements within the documentation.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add cf-mcp
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install cf-mcp
```

## Usage

To start the MCP server, run the following command in your terminal:

```bash
cf-mcp stdio --root /path/to/cute_framework_project  # STDIO mode
cf-mcp http --root /path/to/cute_framework_project   # HTTP mode with web UI
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pusewicz/cf-mcp.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
