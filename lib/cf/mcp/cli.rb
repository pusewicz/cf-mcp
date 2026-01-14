# frozen_string_literal: true

require "optparse"
require_relative "index_builder"
require_relative "server"

module CF
  module MCP
    class CLI
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
        builder = IndexBuilder.new(root: @options[:root], download: @options[:download])

        unless builder.valid?
          warn "Error: Headers directory not found: #{builder.headers_path}"
          warn "Use --root to specify the path to Cute Framework headers"
          warn "Or use --download to fetch headers from GitHub"
          exit 1
        end

        warn "Parsing headers from: #{builder.headers_path}"
        index = builder.build do |event, path, count|
          warn "Indexed #{count} topics from: #{path}" if event == :topics_indexed
        end
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
    end
  end
end
