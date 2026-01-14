# frozen_string_literal: true

require "optparse"
require_relative "parser"
require_relative "topic_parser"
require_relative "index"
require_relative "server"
require_relative "downloader"

module CF
  module MCP
    class CLI
      DEFAULT_HEADERS_PATH = File.expand_path("~/Work/GitHub/pusewicz/cute_framework/include")

      def initialize(args)
        @args = args
        @options = parse_args
      end

      def run
        case @options[:command]
        when :stdio
          run_server(:stdio)
        when :http
          run_http_server
        when :help
          puts @option_parser
        else
          warn "Unknown command. Use --help for usage information."
          exit 1
        end
      end

      private

      def parse_args
        options = {
          command: nil,
          port: nil,
          host: "0.0.0.0",
          root: nil,
          download: false
        }

        @option_parser = OptionParser.new do |opts|
          opts.banner = "Usage: cf-mcp <command> [options]"
          opts.separator ""
          opts.separator "Commands:"
          opts.separator "  stdio    Run in STDIO mode (for CLI integration)"
          opts.separator "  http     Run as HTTP server with web interface"
          opts.separator ""
          opts.separator "Options:"

          opts.on("-r", "--root PATH", "Path to Cute Framework headers directory") do |path|
            options[:root] = path
          end

          opts.on("-p", "--port PORT", Integer, "Port for HTTP server (default: 9292)") do |port|
            options[:port] = port
          end

          opts.on("-H", "--host HOST", "Host to bind to (default: 0.0.0.0)") do |host|
            options[:host] = host
          end

          opts.on("-d", "--download", "Download Cute Framework headers from GitHub") do
            options[:download] = true
          end

          opts.on("-h", "--help", "Show this help message") do
            options[:command] = :help
          end

          opts.on("-v", "--version", "Show version") do
            puts "cf-mcp #{CF::MCP::VERSION}"
            exit 0
          end
        end

        @option_parser.parse!(@args)

        # Parse command from remaining args
        if options[:command].nil? && !@args.empty?
          command = @args.shift.to_sym
          options[:command] = command if [:stdio, :http].include?(command)
        end

        options[:command] ||= :help
        options
      end

      def run_server(mode)
        headers_path = resolve_headers_path

        unless File.directory?(headers_path)
          warn "Error: Headers directory not found: #{headers_path}"
          warn "Use --root to specify the path to Cute Framework headers"
          warn "Or use --download to fetch headers from GitHub"
          exit 1
        end

        warn "Parsing headers from: #{headers_path}"
        index = build_index(headers_path)
        warn "Indexed #{index.stats[:total]} items (#{index.stats[:functions]} functions, #{index.stats[:structs]} structs, #{index.stats[:enums]} enums)"

        server = Server.new(index)
        server.run_stdio
      end

      def run_http_server
        require "rackup"

        port = @options[:port] || 9292
        host = @options[:host]

        app = HTTPServer.build_rack_app(
          root: @options[:root],
          download: @options[:download]
        )

        warn "Starting HTTP server on #{host}:#{port}..."
        warn "Web interface available at http://localhost:#{port}/"
        warn "MCP endpoint available at http://localhost:#{port}/http"
        Rackup::Server.start(app: app, Host: host, Port: port, Logger: $stderr)
      end

      def resolve_headers_path
        return @options[:root] if @options[:root]
        return ENV["CF_HEADERS_PATH"] if ENV["CF_HEADERS_PATH"]

        if @options[:download]
          warn "Downloading Cute Framework headers from GitHub..."
          downloader = Downloader.new
          path = downloader.download_and_extract
          warn "Downloaded headers to: #{path}"
          return path
        end

        DEFAULT_HEADERS_PATH
      end

      def build_index(headers_path)
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

      def find_topics_path(headers_path)
        # If headers_path is .../cute_framework/include, topics is at .../cute_framework/docs/topics
        base = File.dirname(headers_path)
        topics_path = File.join(base, "docs", "topics")
        return topics_path if File.directory?(topics_path)

        # Alternative: topics directly under headers parent
        topics_path = File.join(base, "topics")
        return topics_path if File.directory?(topics_path)

        nil
      end

      def refine_topic_references(topic, index)
        # Move items from struct_references to enum_references if they're actually enums
        topic.struct_references.dup.each do |ref|
          item = index.find(ref)
          next unless item

          if item.type == :enum
            topic.struct_references.delete(ref)
            topic.enum_references << ref unless topic.enum_references.include?(ref)
          end
        end
      end
    end
  end
end
