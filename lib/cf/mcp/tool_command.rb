# frozen_string_literal: true

require "optparse"

module CF
  module MCP
    # Runs an MCP tool as a command, mapping its input schema onto the command
    # line: required properties are positional arguments, the rest are flags.
    class ToolCommand
      Property = Data.define(:name, :type, :description, :values)

      def initialize(tool)
        @tool = tool
        schema = tool.input_schema.to_h
        required = schema.fetch(:required, []).map(&:to_sym)
        properties = schema.fetch(:properties).map do |name, spec|
          Property.new(name: name, type: spec[:type], description: spec[:description].to_s, values: spec[:enum])
        end
        @required, @flags = properties.partition { |property| required.include?(property.name) }
        # A tool that requires nothing still takes its first property as an optional argument.
        @arguments = @required.empty? ? properties.first(1) : @required
        @parser = build_parser
      end

      # Returns the process exit status.
      def run(args)
        flags = {} #: Hash[Symbol, untyped]
        positionals = @parser.parse(args, into: flags)
        return print_help if flags.key?(:help)

        respond(call_tool(bind(positionals).merge(flags)))
      end

      private

      def build_parser
        OptionParser.new do |opts|
          opts.banner = ["Usage: cf-mcp", @tool.tool_name, *@arguments.map { |argument| usage(argument) }, "[options]"].join(" ")
          opts.separator ""
          opts.separator @tool.description.to_s
          unless @arguments.empty?
            opts.separator ""
            opts.separator "Arguments:"
            @arguments.each { |argument| opts.separator "    #{placeholder(argument).ljust(32)}#{argument.description}" }
          end
          opts.separator ""
          opts.separator "Options:"
          @flags.each { |flag| define_flag(opts, flag) }
          opts.on("-h", "--help", "Show this help message")
        end
      end

      def define_flag(opts, flag)
        switch = "--#{flag.name} #{placeholder(flag)}"
        if (values = flag.values)
          opts.on(switch, values, "#{flag.description} [#{values.join("|")}]")
        elsif flag.type == "integer"
          opts.on(switch, Integer, flag.description)
        elsif flag.type == "boolean"
          opts.on("--[no-]#{flag.name}", flag.description)
        else
          opts.on(switch, flag.description)
        end
      end

      def placeholder(property)
        property.name.to_s.upcase
      end

      # How an argument reads in the usage line: optional ones are bracketed.
      def usage(argument)
        @required.include?(argument) ? placeholder(argument) : "[#{placeholder(argument)}]"
      end

      def bind(positionals)
        if positionals.size < @required.size
          raise OptionParser::MissingArgument, placeholder(@required.fetch(positionals.size))
        end
        if positionals.size > @arguments.size
          raise OptionParser::NeedlessArgument, positionals.drop(@arguments.size).join(" ")
        end

        @arguments.first(positionals.size).map(&:name).zip(positionals).to_h
      end

      def call_tool(arguments)
        # `MCP::Tool.call` is deliberately undeclared (see sig-stubs/mcp.rbs), so it is sent.
        @tool.public_send(:call, **arguments) #: ::MCP::Tool::Response
      end

      def respond(response)
        text = response.content.filter_map { |item| item[:text] }.join("\n")
        if response.error?
          warn text
          1
        else
          puts text
          0
        end
      end

      def print_help
        puts @parser
        0
      end
    end
  end
end
