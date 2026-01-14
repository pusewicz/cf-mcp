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
    end

    # HTTP server with web interface at root and MCP endpoint at /http
    class HTTPServer
      # Build a rack app with automatic header downloading and indexing
      # This is the shared entry point for both config.ru and CLI
      def self.build_rack_app(root: nil, download: false)
        require_relative "parser"
        require_relative "topic_parser"
        require_relative "index"
        require_relative "downloader"

        headers_path = resolve_headers_path(root: root, download: download)

        unless File.directory?(headers_path)
          raise "Headers directory not found: #{headers_path}. Use root: or download: true"
        end

        warn "Parsing headers from: #{headers_path}"
        index = build_index(headers_path)
        warn "Indexed #{index.stats[:total]} items (#{index.stats[:functions]} functions, #{index.stats[:structs]} structs, #{index.stats[:enums]} enums)"

        new(index).rack_app
      end

      def self.resolve_headers_path(root:, download:)
        return root if root
        return ENV["CF_HEADERS_PATH"] if ENV["CF_HEADERS_PATH"]

        if download
          warn "Downloading Cute Framework headers from GitHub..."
          downloader = Downloader.new
          path = downloader.download_and_extract
          warn "Downloaded headers to: #{path}"
          return path
        end

        File.expand_path("~/Work/GitHub/pusewicz/cute_framework/include")
      end

      def self.build_index(headers_path)
        parser = Parser.new
        index = Index.new

        parser.parse_directory(headers_path).each do |item|
          index.add(item)
        end

        # Parse topics if available
        topics_path = find_topics_path(headers_path)
        if topics_path && File.directory?(topics_path)
          topic_parser = TopicParser.new
          topic_parser.parse_directory(topics_path).each do |topic|
            refine_topic_references(topic, index)
            index.add(topic)
          end
          warn "Indexed #{index.stats[:topics]} topics from: #{topics_path}"
        end

        index
      end

      def self.find_topics_path(headers_path)
        base = File.dirname(headers_path)
        topics_path = File.join(base, "docs", "topics")
        return topics_path if File.directory?(topics_path)

        topics_path = File.join(base, "topics")
        return topics_path if File.directory?(topics_path)

        nil
      end

      def self.refine_topic_references(topic, index)
        topic.struct_references.dup.each do |ref|
          item = index.find(ref)
          next unless item

          if item.type == :enum
            topic.struct_references.delete(ref)
            topic.enum_references << ref unless topic.enum_references.include?(ref)
          end
        end
      end

      private_class_method :resolve_headers_path, :build_index, :find_topics_path, :refine_topic_references

      def initialize(index)
        @index = index
      end

      CORS_HEADERS = {
        "access-control-allow-origin" => "*",
        "access-control-allow-methods" => "GET, POST, DELETE, OPTIONS",
        "access-control-allow-headers" => "Content-Type, Accept, Mcp-Session-Id",
        "access-control-expose-headers" => "Mcp-Session-Id"
      }.freeze

      def rack_app
        require "rack"

        mcp_server = create_mcp_server
        http_transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(mcp_server, stateless: true)
        mcp_server.transport = http_transport

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
          when %r{^/http(/|$)}
            http_transport.handle_request(request)
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
