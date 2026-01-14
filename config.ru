# frozen_string_literal: true

require_relative "lib/cf/mcp"

# Build and run the combined server with automatic header downloading
run CF::MCP::CombinedServer.build_rack_app(download: true)
