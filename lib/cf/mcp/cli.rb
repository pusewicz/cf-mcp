# frozen_string_literal: true

require "optparse"
require_relative "parser"
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
          run_server(:http)
        when :sse
          run_server(:sse)
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
          root: nil,
          download: false
        }

        @option_parser = OptionParser.new do |opts|
          opts.banner = "Usage: cf-mcp <command> [options]"
          opts.separator ""
          opts.separator "Commands:"
          opts.separator "  stdio    Run in STDIO mode (for CLI integration)"
          opts.separator "  http     Run as HTTP server (stateless)"
          opts.separator "  sse      Run as SSE server (stateful with real-time updates)"
          opts.separator ""
          opts.separator "Options:"

          opts.on("-r", "--root PATH", "Path to Cute Framework headers directory") do |path|
            options[:root] = path
          end

          opts.on("-p", "--port PORT", Integer, "Port for HTTP/SSE server (default: 9292 for HTTP, 9393 for SSE)") do |port|
            options[:port] = port
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
          options[:command] = command if [:stdio, :http, :sse].include?(command)
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

        case mode
        when :stdio
          server.run_stdio
        when :http
          port = @options[:port] || 9292
          server.run_http(port: port)
        when :sse
          port = @options[:port] || 9393
          server.run_sse(port: port)
        end
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

        index
      end
    end
  end
end
