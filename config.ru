# frozen_string_literal: true

require_relative "lib/cf/mcp"

# Download headers from GitHub if not already present
warn "Initializing CF::MCP server..."
downloader = CF::MCP::Downloader.new
headers_path = downloader.download_and_extract
warn "Using headers from: #{headers_path}"

# Build the index
warn "Parsing headers..."
parser = CF::MCP::Parser.new
index = CF::MCP::Index.new

parser.parse_directory(headers_path).each do |item|
  index.add(item)
end

warn "Indexed #{index.stats[:total]} items (#{index.stats[:functions]} functions, #{index.stats[:structs]} structs, #{index.stats[:enums]} enums)"

# Create and run the combined server with both SSE and HTTP transports
# - / and /sse - SSE transport (stateful, for Claude Desktop)
# - /http - HTTP transport (stateless, for simple integrations)
server = CF::MCP::CombinedServer.new(index)
run server.rack_app
