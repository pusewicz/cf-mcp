# frozen_string_literal: true

require "optparse"

module CF
  module MCP
    class CLI
      USAGE = "Usage: cf-mcp [options] <command> [options]"

      COMMANDS = {
        "stdio" => "Run in STDIO mode (for CLI integration)",
        "http" => "Run as HTTP server with web interface",
        "index" => "Index the documentation into a cache for fast lookups"
      }.freeze

      def initialize(args)
        @args = args
        @options = {
          port: nil,
          host: "0.0.0.0",
          root: nil,
          download: false,
          help: false,
          version: false
        } #: options
        @option_parser = build_option_parser
      end

      # Returns the process exit status.
      def run
        @option_parser.order!(@args)
        command = @args.shift&.tr("-", "_")
        tool = find_tool(command)
        # A tool's flags are checked against the index, so the options that choose it come out first.
        tool ? take_source_options : @option_parser.parse!(@args)

        return print_version if @options[:version]
        return print_usage if @options[:help] || [nil, "help"].include?(command)
        return run_tool(tool) if tool
        return fail_with("Unexpected arguments: #{@args.join(" ")}") unless @args.empty?

        case command
        when "stdio" then run_stdio
        when "http" then run_http
        when "index" then run_index
        else fail_with("Unknown command '#{command}'. Use --help for usage information.")
        end
      rescue OptionParser::ParseError, Error => e
        fail_with(e.message)
      end

      private

      def build_option_parser
        OptionParser.new do |opts|
          opts.banner = USAGE
          opts.separator ""
          opts.separator "Options:"

          opts.on("-r", "--root PATH", "Path to Cute Framework headers directory") do |path|
            @options[:root] = path
          end

          opts.on("-p", "--port PORT", Integer, "Port for HTTP server (default: 9292)") do |port|
            @options[:port] = port
          end

          opts.on("-H", "--host HOST", "Host to bind to (default: 0.0.0.0)") do |host|
            @options[:host] = host
          end

          opts.on("-d", "--download", "Download Cute Framework headers from GitHub") do
            @options[:download] = true
          end

          opts.on("-h", "--help", "Show this help message") do
            @options[:help] = true
          end

          opts.on("-v", "--version", "Show version") do
            @options[:version] = true
          end
        end
      end

      def print_version
        puts "cf-mcp #{VERSION}"
        0
      end

      # The commands go in the banner because the tools are only loaded when asked for.
      def print_usage
        @option_parser.banner = [
          USAGE, "",
          "Commands:", *command_lines(COMMANDS), "",
          "Documentation commands (see `cf-mcp <command> --help`):", *command_lines(tool_descriptions)
        ].join("\n")
        puts @option_parser
        0
      end

      def command_lines(descriptions)
        descriptions.map { |name, description| "  #{name.ljust(18)}#{description}" }
      end

      def tool_descriptions
        Tools.all.to_h { |tool| [tool.tool_name.to_s, tool.description.to_s] }
      end

      def fail_with(message)
        warn "Error: #{message}"
        1
      end

      def run_stdio
        builder = IndexBuilder.new(root: @options[:root], download: @options[:download])
        return fail_with(missing_headers_message(builder)) unless builder.valid?

        warn "Parsing headers from: #{builder.headers_path}"
        index = builder.build do |event, path, count|
          warn "Indexed #{count} topics from: #{path}" if event == :topics_indexed
        end
        warn "Indexed #{index.stats[:total]} items (#{index.stats[:functions]} functions, #{index.stats[:structs]} structs, #{index.stats[:enums]} enums)"
        warn "Cute Framework revision: #{builder.revision}" if builder.revision

        Server.new(index, revision: builder.revision).run_stdio
        0
      end

      def run_http
        require "rackup"

        port = @options[:port] || 9292
        host = @options[:host]

        app = Server.build_rack_app(
          root: @options[:root],
          download: @options[:download]
        )

        warn "Starting HTTP server on #{host}:#{port}..."
        warn "Web interface available at http://localhost:#{port}/"
        warn "MCP endpoint available at http://localhost:#{port}/http"
        Rackup::Server.start(app: app, Host: host, Port: port, Logger: $stderr)
        0
      end

      def run_index
        cache = IndexCache.new
        stats = cache.refresh(index_source) { |source| IndexBuilder.new(**source) }.stats

        puts "Indexed #{stats[:total]} items (#{stats[:functions]} functions, #{stats[:structs]} structs, #{stats[:enums]} enums, #{stats[:topics]} topics)"
        puts "Cute Framework revision: #{cache.revision}" if cache.revision
        puts "Cached at #{cache.path}"
        0
      end

      # Takes --root and --download out of the arguments wherever they stand, leaving the rest for the tool.
      def take_source_options
        rest = [] #: Array[String]
        while (arg = @args.shift)
          case arg
          when "-r", "--root" then @options[:root] = @args.shift || raise(OptionParser::MissingArgument, arg)
          when /\A--root=(.*)\z/ then @options[:root] = $1
          when "-d", "--download" then @options[:download] = true
          else rest << arg
          end
        end
        @args.replace(rest)
      end

      # The tool named by the command, if it names one. Asking loads the tools, which the
      # other commands have no need of.
      def find_tool(command)
        return if command.nil? || COMMANDS.key?(command)

        Tools.all.find { |tool| tool.tool_name == command }
      end

      # Help describes the tool from its schema alone, so it goes without the index.
      def run_tool(tool)
        IndexCache.new.index(index_source) { |source| IndexBuilder.new(**source) } unless @args.intersect?(%w[-h --help])
        ToolCommand.new(tool).run(@args)
      end

      # What the user asked to index, by flag or CF_HEADERS_PATH; nil leaves the choice to the
      # cache. The root is expanded so every spelling of it names the same index.
      def index_source
        root = @options[:root] || ENV["CF_HEADERS_PATH"]
        {root: root && File.expand_path(root), download: @options[:download]} if root || @options[:download]
      end

      def missing_headers_message(builder)
        "Headers directory not found: #{builder.headers_path}. Use --root to specify the path to Cute Framework headers, or --download to fetch them from GitHub."
      end
    end
  end
end
