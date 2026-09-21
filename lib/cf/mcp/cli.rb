# frozen_string_literal: true

require "optparse"

module CF
  module MCP
    class CLI
      # Tool names are listed here, not read from Tools.all: naming a tool
      # loads it, and that must wait until the index is filled.
      TOOL_COMMANDS = %w[search get_details find_related get_topic member_search parameter_search list_category list_topics].freeze

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
        tool_command = TOOL_COMMANDS.find { |name| name == command }
        # A tool's flags are only known once its index is loaded, which needs the source options first.
        tool_command ? take_source_options : @option_parser.parse!(@args)

        return print_version if @options[:version]
        return print_usage if @options[:help] || [nil, "help"].include?(command)
        return run_tool(tool_command) if tool_command
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
          opts.banner = "Usage: cf-mcp [options] <command> [options]"
          opts.separator ""
          opts.separator "Commands:"
          opts.separator "  stdio    Run in STDIO mode (for CLI integration)"
          opts.separator "  http     Run as HTTP server with web interface"
          opts.separator "  index    Index the documentation into a cache for fast lookups"
          opts.separator ""
          opts.separator "Documentation commands (see `cf-mcp <command> --help`):"
          opts.separator "  #{TOOL_COMMANDS.join(", ")}"
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

      def print_usage
        puts @option_parser
        0
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

      def run_tool(name)
        IndexCache.new.index(index_source) { |source| IndexBuilder.new(**source) }
        tool = Tools.all.find { |candidate| candidate.tool_name == name } || raise(Error, "No tool named '#{name}'")
        ToolCommand.new(tool).run(@args)
      end

      # What the user asked to index; nil leaves the choice to the cache.
      def index_source
        {root: @options[:root], download: @options[:download]} if @options[:root] || @options[:download]
      end

      def missing_headers_message(builder)
        "Headers directory not found: #{builder.headers_path}. Use --root to specify the path to Cute Framework headers, or --download to fetch them from GitHub."
      end
    end
  end
end
