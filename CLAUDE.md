# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CF::MCP is a Ruby gem that implements an MCP (Model Context Protocol) server for the Cute Framework, a C/C++ 2D game framework. It indexes header files and extracts documentation from comments, providing search functionality for structs, classes, functions, and other elements.

The server operates in three modes:
- **STDIO Mode**: For integration with CLI tools via standard input/output
- **HTTP Mode**: Stateless HTTP server for simple request/response and multi-node deployments
- **SSE Mode**: Stateful HTTP server with Server-Sent Events for real-time notifications

## Commands

```bash
# Install dependencies
bin/setup

# Run all tests
rake test

# Run a single test file
ruby -Ilib:test test/cf/test_mcp.rb

# Run a specific test method
ruby -Ilib:test test/cf/test_mcp.rb --name test_that_it_has_a_version_number

# Lint code with Standard Ruby
rake standard

# Auto-fix linting issues
rake standard:fix

# Run both tests and linting (default task)
rake

# Start interactive console
bin/console

# Install gem locally
bundle exec rake install
```

## Architecture

- `lib/cf/mcp.rb` - Main module entry point, defines `CF::MCP` namespace
- `lib/cf/mcp/version.rb` - Version constant
- `exe/cf-mcp` - CLI executable
- `sig/cf/mcp.rbs` - RBS type signatures

## Code Style

Uses Standard Ruby for linting (configured in `.standard.yml`). Target Ruby version is 3.2+.

## Local Development

The local Cute Framework checkout is at `~/Work/GitHub/pusewicz/cute_framework`. Use this path when testing:

```bash
cf-mcp stdio --root ~/Work/GitHub/pusewicz/cute_framework
```

## MCP SDK Reference

This project uses the `mcp` gem (Ruby MCP SDK). Key patterns:

### Server Setup
```ruby
server = MCP::Server.new(
  name: "cf-mcp",
  version: CF::MCP::VERSION,
  tools: [MyTool],
  prompts: [MyPrompt],
  resources: [my_resource]
)
```

### Defining Tools (Class-based)
```ruby
class MyTool < MCP::Tool
  description "Tool description"
  input_schema(properties: { query: { type: "string" } }, required: ["query"])

  def self.call(query:, server_context:)
    MCP::Tool::Response.new([{ type: "text", text: "Result" }])
  end
end
```

### Defining Tools (Dynamic)
```ruby
server.define_tool(name: "echo", description: "Echo a message") do |args, server_context:|
  message = args[:message]
  MCP::Tool::Response.new([{ type: "text", text: "Echo: #{message}" }])
end
```

### Defining Prompts
```ruby
class MyPrompt < MCP::Prompt
  prompt_name "my_prompt"
  description "Prompt description"
  arguments [MCP::Prompt::Argument.new(name: "message", description: "Input message", required: true)]

  def self.template(args, server_context:)
    MCP::Prompt::Result.new(
      messages: [MCP::Prompt::Message.new(role: "user", content: MCP::Content::Text.new(args[:message]))]
    )
  end
end
```

### STDIO Transport
```ruby
transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open  # Blocks, reading JSON-RPC from stdin, writing to stdout
```

### HTTP Transport (Stateless)
```ruby
transport = MCP::Server::Transports::StreamableHTTPTransport.new(server, stateless: true)
server.transport = transport

app = Rack::Builder.new do
  use Rack::CommonLogger
  run ->(env) { transport.handle_request(env) }
end

Rackup::Server.start(app: app, Port: 9292)
```

### SSE Transport (Stateful with Server-Sent Events)
```ruby
transport = MCP::Server::Transports::StreamableHTTPTransport.new(server)
server.transport = transport

app = Rack::Builder.new do
  use Rack::CommonLogger
  use Rack::ShowExceptions
  run ->(env) { transport.handle_request(env) }
end

Rackup::Server.start(app: app, Port: 9393)
```

### SSE Protocol Flow
1. Client POSTs `initialize` method → Server returns `Mcp-Session-Id` header
2. Client opens GET for SSE stream using session ID (for real-time notifications)
3. Client sends JSON-RPC requests via POST with `Mcp-Session-Id` header
4. Client sends DELETE to terminate session

### Sending Notifications (SSE mode only)
```ruby
server.notify_tools_list_changed
server.notify_prompts_list_changed
server.notify_resources_list_changed
```

### Resources
```ruby
resource = MCP::Resource.new(
  uri: "file:///path/to/doc",
  name: "resource-name",
  mime_type: "text/plain"
)

server = MCP::Server.new(
  name: "cf-mcp",
  version: CF::MCP::VERSION,
  tools: [MyTool],
  resources: [resource]
)

server.resources_read_handler do |params|
  [{ uri: params[:uri], mimeType: "text/plain", text: "content" }]
end
```

## References

### MCP SDK Examples
- [STDIO Server](https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/refs/heads/main/examples/stdio_server.rb)
- [HTTP Server](https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/refs/heads/main/examples/http_server.rb)
- [SSE Server](https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/refs/heads/main/examples/streamable_http_server.rb)

### Cute Framework
- [Docs Parser (C++)](https://raw.githubusercontent.com/RandyGaul/cute_framework/refs/heads/master/samples/docs_parser.cpp) - Reference implementation for parsing Cute Framework header documentation
