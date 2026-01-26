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

      CORS_HEADERS = {
        "access-control-allow-origin" => "*",
        "access-control-allow-methods" => "GET, POST, DELETE, OPTIONS",
        "access-control-allow-headers" => "Content-Type, Accept, Mcp-Session-Id",
        "access-control-expose-headers" => "Mcp-Session-Id"
      }.freeze

      # Build a rack app with automatic header downloading and indexing
      # This is the shared entry point for both config.ru and CLI
      def self.build_rack_app(root: nil, download: false)
        require_relative "index_builder"

        builder = IndexBuilder.new(root: root, download: download)

        unless builder.valid?
          raise "Headers directory not found: #{builder.headers_path}. Use root: or download: true"
        end

        warn "Parsing headers from: #{builder.headers_path}"
        index = builder.build do |event, path, count|
          warn "Indexed #{count} topics from: #{path}" if event == :topics_indexed
        end
        warn "Indexed #{index.stats[:total]} items (#{index.stats[:functions]} functions, #{index.stats[:structs]} structs, #{index.stats[:enums]} enums)"

        new(index).rack_app
      end

      PROTOCOL_VERSION = "2025-06-18"
      WEBSITE_URL = ENV.fetch("FLY_APP_NAME", nil) ? "https://#{ENV["FLY_APP_NAME"]}.fly.dev" : "https://cf-mcp.fly.dev"
      LOGO_PATH = "/logo.svg"
      PUBLIC_DIR = File.join(__dir__, "public")

      def initialize(index)
        @index = index
        configuration = ::MCP::Configuration.new(protocol_version: PROTOCOL_VERSION)
        @server = ::MCP::Server.new(
          name: "cf-mcp",
          title: "Cute Framework MCP",
          configuration:,
          version: CF::MCP::VERSION,
          website_url: WEBSITE_URL,
          icons: [
            ::MCP::Icon.new(src: "#{WEBSITE_URL}#{LOGO_PATH}", mime_type: "image/svg+xml")
          ],
          tools: TOOLS,
          resources: build_topic_resources(index)
        )
        @server.server_context = {index: index}

        # Register handler for reading resource content
        @server.resources_read_handler do |params|
          handle_resource_read(params, index)
        end
      end

      def run_stdio
        transport = ::MCP::Server::Transports::StdioTransport.new(@server)
        transport.open
      end

      def rack_app
        require "rack"

        http_transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(@server, stateless: true)
        @server.transport = http_transport

        landing_page = build_landing_page
        index = @index
        tools = TOOLS
        cors_headers = CORS_HEADERS
        public_dir = PUBLIC_DIR

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
          when %r{^/http(/|$)}
            http_transport.handle_request(request)
          when "/logo.svg"
            # Serve logo as static asset
            logo_path = File.join(public_dir, "logo.svg")
            if File.exist?(logo_path)
              [200, {"content-type" => "image/svg+xml", "cache-control" => "public, max-age=86400"}, [File.read(logo_path)]]
            else
              [404, {"content-type" => "text/plain"}, ["Not found"]]
            end
          else
            # Default route - show landing page for browsers
            accept = request.get_header("HTTP_ACCEPT") || ""
            if request.get? && accept.include?("text/html")
              [200, {"content-type" => "text/html; charset=utf-8"}, [landing_page.call(index, tools)]]
            else
              # For non-browser clients at root, redirect to /http
              [301, {"location" => "/http", "content-type" => "text/plain"}, ["Redirecting to /http"]]
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

      def build_topic_resources(index)
        index.topics.map do |topic|
          ::MCP::Resource.new(
            uri: "cf://topics/#{topic.name}",
            name: topic.name.tr("_", " ").split.map(&:capitalize).join(" "),
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

      def escape_html(text)
        text.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub('"', "&quot;")
          .gsub("'", "&#39;")
      end

      def build_landing_page
        require "erb"
        require "json"

        template_path = File.join(__dir__, "templates", "index.erb")
        template = ERB.new(File.read(template_path))

        ->(index, tool_classes) {
          context = TemplateContext.new(
            version: CF::MCP::VERSION,
            protocol_version: PROTOCOL_VERSION,
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

        attr_reader :version, :protocol_version, :stats, :categories, :topics, :tools, :tool_schemas_json

        def initialize(version:, protocol_version:, stats:, categories:, topics:, tools:, tool_schemas_json:)
          @version = version
          @protocol_version = protocol_version
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
