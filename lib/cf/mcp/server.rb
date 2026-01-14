# frozen_string_literal: true

require "mcp"
require_relative "tools/search_tool"
require_relative "tools/search_functions"
require_relative "tools/search_structs"
require_relative "tools/search_enums"
require_relative "tools/list_category"
require_relative "tools/get_details"

module CF
  module MCP
    class Server
      attr_reader :server, :index

      TOOLS = [
        Tools::SearchTool,
        Tools::SearchFunctions,
        Tools::SearchStructs,
        Tools::SearchEnums,
        Tools::ListCategory,
        Tools::GetDetails
      ].freeze

      def initialize(index)
        @index = index
        @server = ::MCP::Server.new(
          name: "cf-mcp",
          version: CF::MCP::VERSION,
          tools: TOOLS
        )
        @server.server_context = {index: index}
      end

      def run_stdio
        transport = ::MCP::Server::Transports::StdioTransport.new(@server)
        transport.open
      end

      def run_http(port: 9292)
        require "rackup"

        app = http_app
        warn "Starting HTTP server on port #{port}..."
        warn "Index contains #{@index.size} items"
        Rackup::Server.start(app: app, Port: port, Logger: $stderr)
      end

      def http_app
        require "rack"

        transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(@server, stateless: true)
        @server.transport = transport

        build_rack_app(transport)
      end

      def run_sse(port: 9393)
        require "rack"
        require "rackup"

        transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(@server)
        @server.transport = transport

        app = build_rack_app(transport)
        warn "Starting SSE server on port #{port}..."
        warn "Index contains #{@index.size} items"
        Rackup::Server.start(app: app, Port: port, Logger: $stderr)
      end

      private

      def build_rack_app(transport)
        Rack::Builder.new do
          use Rack::CommonLogger
          run ->(env) { transport.handle_request(Rack::Request.new(env)) }
        end
      end
    end
  end
end
