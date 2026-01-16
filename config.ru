# frozen_string_literal: true

require_relative "lib/cf/mcp"

# Build and run the HTTP server with automatic header downloading
run CF::MCP::Server.build_rack_app(download: true)
