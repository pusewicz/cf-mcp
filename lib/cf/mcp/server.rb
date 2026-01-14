# frozen_string_literal: true

require "mcp"
require_relative "tools/search_tool"
require_relative "tools/search_functions"
require_relative "tools/search_structs"
require_relative "tools/search_enums"
require_relative "tools/list_category"
require_relative "tools/get_details"
require_relative "tools/find_related"
require_relative "tools/parameter_search"
require_relative "tools/member_search"
require_relative "tools/list_topics"
require_relative "tools/get_topic"

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
        Tools::GetDetails,
        Tools::FindRelated,
        Tools::ParameterSearch,
        Tools::MemberSearch,
        Tools::ListTopics,
        Tools::GetTopic
      ].freeze

      def initialize(index)
        @index = index
        @server = ::MCP::Server.new(
          name: "cf-mcp",
          version: CF::MCP::VERSION,
          tools: TOOLS,
          resources: build_topic_resources(index)
        )
        @server.server_context = {index: index}

        # Register handler for reading resource content
        @server.resources_read_handler do |params|
          handle_resource_read(params, index)
        end
      end

      private

      def build_topic_resources(index)
        index.topics.map do |topic|
          ::MCP::Resource.new(
            uri: "cf://topics/#{topic.name}",
            name: topic.name,
            title: topic.name.tr("_", " ").split.map(&:capitalize).join(" "),
            description: topic.brief,
            mime_type: "text/markdown"
          )
        end
      end

      def handle_resource_read(params, index)
        uri = params[:uri]
        return [] unless uri&.start_with?("cf://topics/")

        topic_name = uri.sub("cf://topics/", "")
        topic = index.find(topic_name)

        return [] unless topic&.type == :topic

        [{
          uri: uri,
          mimeType: "text/markdown",
          text: topic.content
        }]
      end

      public

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
        require "erb"
        require "json"

        template_path = File.join(__dir__, "templates", "index.erb")
        template = ERB.new(File.read(template_path))

        ->(index, tool_classes) {
          context = TemplateContext.new(
            version: CF::MCP::VERSION,
            stats: index.stats,
            categories: index.categories.sort,
            topics: index.topics_ordered.map { |t| {name: t.name, brief: t.brief} },
            tools: tool_classes.map { |tool|
              name = tool.respond_to?(:tool_name) ? tool.tool_name : tool.name
              desc = tool.respond_to?(:description) ? tool.description : ""
              {name: name, description: desc}
            },
            tool_schemas_json: tool_classes.map { |tool|
              name = tool.respond_to?(:tool_name) ? tool.tool_name : tool.name
              desc = tool.respond_to?(:description) ? tool.description : ""
              schema = tool.input_schema.to_h
              {name: name, description: desc, inputSchema: schema}
            }.to_json
          )
          template.result(context.get_binding)
        }
      end

      # Helper class to provide a clean binding for ERB templates
      class TemplateContext
        TEMPLATES_DIR = File.join(__dir__, "templates")

        attr_reader :version, :stats, :categories, :topics, :tools, :tool_schemas_json

        def initialize(version:, stats:, categories:, topics:, tools:, tool_schemas_json:)
          @version = version
          @stats = stats
          @categories = categories
          @topics = topics
          @tools = tools
          @tool_schemas_json = tool_schemas_json
        end

        def categories_json
          @categories.to_json
        end

        def topics_json
          @topics.to_json
        end

        def css_content
          File.read(File.join(TEMPLATES_DIR, "style.css"))
        end

        def changelog_content
          changelog_path = CF::MCP.root.join("CHANGELOG.md")
          changelog_path.exist? ? changelog_path.read : ""
        end

        def changelog_json
          changelog_content.to_json
        end

        def js_content
          js = File.read(File.join(TEMPLATES_DIR, "script.js"))
          js.sub("TOOL_SCHEMAS_PLACEHOLDER", @tool_schemas_json)
            .sub("CATEGORIES_PLACEHOLDER", categories_json)
            .sub("TOPICS_PLACEHOLDER", topics_json)
            .sub("CHANGELOG_PLACEHOLDER", changelog_json)
        end

        def h(text)
          text.to_s
            .gsub("&", "&amp;")
            .gsub("<", "&lt;")
            .gsub(">", "&gt;")
            .gsub('"', "&quot;")
            .gsub("'", "&#39;")
        end

        def get_binding
          binding
        end
      end
    end
  end
end
