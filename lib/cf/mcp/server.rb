# frozen_string_literal: true

require "mcp"

module CF
  module MCP
    class Server
      attr_reader :server, :index, :revision

      CUTE_FRAMEWORK_COMMIT_URL_TEMPLATE = "https://github.com/RandyGaul/cute_framework/commit/%{revision}"

      CORS_HEADERS = {
        "access-control-allow-origin" => "*",
        "access-control-allow-methods" => "GET, POST, DELETE, OPTIONS",
        "access-control-allow-headers" => "Content-Type, Accept, MCP-Protocol-Version, Mcp-Method, Mcp-Name, Mcp-Session-Id",
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
        warn "Cute Framework revision: #{builder.revision}" if builder.revision

        new(index, revision: builder.revision).rack_app
      end

      # Modern clients carry their version on every request (no handshake); legacy
      # clients negotiate through `initialize`. Both track the SDK rather than pinning.
      MODERN_PROTOCOL_VERSION = ::MCP::Configuration::LATEST_MODERN_PROTOCOL_VERSION
      LEGACY_PROTOCOL_VERSION = ::MCP::Configuration::LATEST_HANDSHAKE_PROTOCOL_VERSION
      DESCRIPTION = "Search and browse Cute Framework API documentation: functions, structs, enums, and topic guides."
      WEBSITE_URL = ENV.fetch("FLY_APP_NAME", nil) ? "https://#{ENV["FLY_APP_NAME"]}.fly.dev" : "https://cf-mcp.fly.dev"
      PUBLIC_DIR = File.join(__dir__, "public")
      ALLOWED_HOSTS_ENV = "CF_MCP_ALLOWED_HOSTS"

      # Comma-separated list of extra Host header values the HTTP transport accepts
      # (the MCP SDK only allows loopback hosts by default).
      def self.allowed_hosts_from_env(env = ENV)
        env.fetch(ALLOWED_HOSTS_ENV, "").split(",").map(&:strip).reject(&:empty?)
      end

      def initialize(index, revision: nil, allowed_hosts: self.class.allowed_hosts_from_env)
        @index = index
        @revision = revision
        @allowed_hosts = allowed_hosts

        @server = ::MCP::Server.new(
          name: "cf-mcp",
          title: "Cute Framework MCP",
          description: DESCRIPTION,
          version: CF::MCP::VERSION,
          website_url: WEBSITE_URL,
          icons: [
            ::MCP::Icon.new(src: "#{WEBSITE_URL}/favicon.svg", mime_type: "image/svg+xml", sizes: ["any"]),
            ::MCP::Icon.new(src: "#{WEBSITE_URL}/favicon-96x96.png", mime_type: "image/png", sizes: ["96x96"])
          ],
          tools: [
            Tools::SearchTool,
            Tools::ListCategory,
            Tools::GetDetails,
            Tools::FindRelated,
            Tools::ParameterSearch,
            Tools::MemberSearch,
            Tools::ListTopics,
            Tools::GetTopic
          ],
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

        http_transport = ::MCP::Server::Transports::StreamableHTTPTransport.new(@server, stateless: true, allowed_hosts: @allowed_hosts)
        @server.transport = http_transport

        landing_page = build_landing_page
        index = @index
        tools = @server.tools.values
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
          when %r{^/(favicon|apple-touch-icon|web-app-manifest|site\.webmanifest).*$}
            # Serve static assets from public directory
            filename = path.delete_prefix("/")
            asset_path = File.join(public_dir, filename)
            if File.exist?(asset_path)
              content_type = case filename
              when /\.svg$/ then "image/svg+xml"
              when /\.png$/ then "image/png"
              when /\.ico$/ then "image/x-icon"
              when /\.webmanifest$/ then "application/manifest+json"
              else "application/octet-stream"
              end
              [200, {"content-type" => content_type, "cache-control" => "public, max-age=86400"}, [File.read(asset_path, mode: "rb")]]
            else
              [404, {"content-type" => "text/plain"}, ["Not found"]]
            end
          else
            # Default route - show landing page for browsers
            accept = request.get_header("HTTP_ACCEPT") || ""
            if request.get? && !accept.include?("application/json")
              # Serve HTML by default for GET requests unless client specifically requests JSON
              [200, {"content-type" => "text/html; charset=utf-8"}, [landing_page.call(index, tools)]]
            else
              # For JSON clients or non-GET requests, redirect to MCP endpoint
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
            modern_protocol_version: MODERN_PROTOCOL_VERSION,
            legacy_protocol_version: LEGACY_PROTOCOL_VERSION,
            revision: @revision,
            revision_url: @revision && format(CUTE_FRAMEWORK_COMMIT_URL_TEMPLATE, revision: @revision),
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

        attr_reader :version, :modern_protocol_version, :legacy_protocol_version, :revision, :revision_url, :stats, :categories, :topics, :tools, :tool_schemas_json

        def initialize(version:, modern_protocol_version:, legacy_protocol_version:, revision:, revision_url:, stats:, categories:, topics:, tools:, tool_schemas_json:)
          @version = version
          @modern_protocol_version = modern_protocol_version
          @legacy_protocol_version = legacy_protocol_version
          @revision = revision
          @revision_url = revision_url
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
          # Substitute the scalar placeholders first so injected content can't collide with them
          js.sub("PROTOCOL_VERSION_PLACEHOLDER", @modern_protocol_version.to_json)
            .sub("CLIENT_VERSION_PLACEHOLDER", @version.to_json)
            .sub("TOOL_SCHEMAS_PLACEHOLDER", @tool_schemas_json)
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
