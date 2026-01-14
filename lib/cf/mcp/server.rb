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

      def sse_app
        require "rack"

        transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(@server)
        @server.transport = transport

        build_rack_app(transport)
      end
    end

    # Combined server that exposes both SSE and HTTP transports under different paths
    class CombinedServer
      def initialize(index)
        @index = index
      end

      CORS_HEADERS = {
        "access-control-allow-origin" => "*",
        "access-control-allow-methods" => "GET, POST, DELETE, OPTIONS",
        "access-control-allow-headers" => "Content-Type, Accept, Mcp-Session-Id, Last-Event-ID",
        "access-control-expose-headers" => "Mcp-Session-Id"
      }.freeze

      def rack_app
        require "rack"

        # Create separate server instances for each transport
        sse_server = create_mcp_server
        http_server = create_mcp_server

        sse_transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(sse_server)
        sse_server.transport = sse_transport

        http_transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(http_server, stateless: true)
        http_server.transport = http_transport

        landing_page = build_landing_page
        index = @index
        tools = Server::TOOLS
        cors_headers = CORS_HEADERS

        app = ->(env) {
          request = Rack::Request.new(env)
          path = request.path_info

          # Handle CORS preflight
          if request.options?
            return [204, cors_headers, []]
          end

          # Route based on path
          status, headers, body = case path
          when %r{^/\.well-known/}
            # OAuth discovery - return 404 to indicate no OAuth required
            [404, {"content-type" => "application/json"}, ['{"error":"Not found"}']]
          when %r{^/sse(/|$)}
            sse_transport.handle_request(request)
          when %r{^/http(/|$)}
            http_transport.handle_request(request)
          else
            # Default route - show landing page for browsers, SSE for MCP clients
            accept = request.get_header("HTTP_ACCEPT") || ""
            if request.get? && accept.include?("text/html")
              [200, {"content-type" => "text/html; charset=utf-8"}, [landing_page.call(index, tools)]]
            else
              sse_transport.handle_request(request)
            end
          end

          # Add CORS headers to response
          [status, headers.merge(cors_headers), body]
        }

        Rack::Builder.new do
          use Rack::CommonLogger
          run app
        end
      end

      private

      def escape_html(text)
        text.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub('"', "&quot;")
          .gsub("'", "&#39;")
      end

      def create_mcp_server
        server = ::MCP::Server.new(
          name: "cf-mcp",
          version: CF::MCP::VERSION,
          tools: Server::TOOLS
        )
        server.server_context = {index: @index}
        server
      end

      def build_landing_page
        escape = method(:escape_html)
        ->(index, tools) {
          stats = index.stats
          tools_html = tools.map { |tool|
            name = tool.respond_to?(:tool_name) ? tool.tool_name : tool.name
            desc = tool.respond_to?(:description) ? tool.description : ""
            <<~TOOL
              <div class="tool">
                <div class="tool-name">#{escape.call(name)}</div>
                <div class="tool-desc">#{escape.call(desc)}</div>
              </div>
            TOOL
          }.join
          <<~HTML
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>CF::MCP - Cute Framework MCP Server</title>
              <style>
                * { box-sizing: border-box; }
                body {
                  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                  line-height: 1.6;
                  max-width: 800px;
                  margin: 0 auto;
                  padding: 2rem;
                  background: #0d1117;
                  color: #c9d1d9;
                }
                h1 { color: #58a6ff; margin-bottom: 0.5rem; }
                h2 { color: #58a6ff; margin-top: 2rem; border-bottom: 1px solid #30363d; padding-bottom: 0.5rem; }
                a { color: #58a6ff; }
                code {
                  background: #161b22;
                  padding: 0.2rem 0.4rem;
                  border-radius: 4px;
                  font-size: 0.9em;
                }
                pre {
                  background: #161b22;
                  padding: 1rem;
                  border-radius: 8px;
                  overflow-x: auto;
                  border: 1px solid #30363d;
                }
                pre code { background: none; padding: 0; }
                .stats {
                  display: grid;
                  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
                  gap: 1rem;
                  margin: 1rem 0;
                }
                .stat {
                  background: #161b22;
                  padding: 1rem;
                  border-radius: 8px;
                  text-align: center;
                  border: 1px solid #30363d;
                }
                .stat-value { font-size: 2rem; font-weight: bold; color: #58a6ff; }
                .stat-label { color: #8b949e; font-size: 0.9rem; }
                .endpoint {
                  background: #161b22;
                  padding: 1rem;
                  border-radius: 8px;
                  margin: 0.5rem 0;
                  border: 1px solid #30363d;
                }
                .endpoint-path { font-weight: bold; color: #7ee787; }
                .endpoint-desc { color: #8b949e; margin-top: 0.25rem; }
                .tools { margin: 1rem 0; }
                .tool {
                  background: #161b22;
                  padding: 0.75rem 1rem;
                  border-radius: 8px;
                  margin: 0.5rem 0;
                  border: 1px solid #30363d;
                }
                .tool-name { font-weight: bold; color: #ffa657; }
                .tool-desc { color: #8b949e; font-size: 0.9rem; }
              </style>
            </head>
            <body>
              <h1>CF::MCP <small style="font-size: 0.5em; color: #8b949e;">v#{CF::MCP::VERSION}</small></h1>
              <p>MCP (Model Context Protocol) server for the <a href="https://github.com/RandyGaul/cute_framework">Cute Framework</a>, a C/C++ 2D game framework.</p>

              <div class="stats">
                <div class="stat">
                  <div class="stat-value">#{stats[:total]}</div>
                  <div class="stat-label">Total Items</div>
                </div>
                <div class="stat">
                  <div class="stat-value">#{stats[:functions]}</div>
                  <div class="stat-label">Functions</div>
                </div>
                <div class="stat">
                  <div class="stat-value">#{stats[:structs]}</div>
                  <div class="stat-label">Structs</div>
                </div>
                <div class="stat">
                  <div class="stat-value">#{stats[:enums]}</div>
                  <div class="stat-label">Enums</div>
                </div>
              </div>

              <h2>Endpoints</h2>
              <div class="endpoint">
                <div class="endpoint-path">/ or /sse</div>
                <div class="endpoint-desc">Streamable HTTP (stateful) - for Claude Desktop and Claude Code</div>
              </div>
              <div class="endpoint">
                <div class="endpoint-path">/http</div>
                <div class="endpoint-desc">Streamable HTTP (stateless) - for simple integrations</div>
              </div>

              <h2>Claude Desktop Setup</h2>
              <p>Remote MCP servers require a <strong>Pro, Max, Team, or Enterprise</strong> plan.</p>
              <ol>
                <li>Open Claude Desktop</li>
                <li>Go to <strong>Settings &rarr; Connectors</strong></li>
                <li>Add this URL as a remote MCP server:</li>
              </ol>
              <pre><code>https://cf-mcp.fly.dev/</code></pre>

              <h2>Claude Code CLI Setup</h2>
              <pre><code>claude mcp add --transport http cf-mcp https://cf-mcp.fly.dev/http</code></pre>

              <h2>Available Tools</h2>
              <div class="tools">
                #{tools_html}
              </div>

              <h2>Links</h2>
              <ul>
                <li><a href="https://github.com/pusewicz/cf-mcp">CF::MCP on GitHub</a></li>
                <li><a href="https://github.com/RandyGaul/cute_framework">Cute Framework</a></li>
                <li><a href="https://modelcontextprotocol.io">Model Context Protocol</a></li>
              </ul>
            </body>
            </html>
          HTML
        }
      end
    end
  end
end
