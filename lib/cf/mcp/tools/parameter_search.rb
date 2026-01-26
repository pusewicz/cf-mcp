# frozen_string_literal: true

require "mcp"
require_relative "response_helpers"

module CF
  module MCP
    module Tools
      class ParameterSearch < ::MCP::Tool
        extend ResponseHelpers

        TITLE = "Parameter Search"

        tool_name "parameter_search"
        title TITLE
        description "Find Cute Framework functions by parameter or return type"

        input_schema(
          type: "object",
          properties: {
            type: {type: "string", description: "Type name to search for (e.g., 'CF_Sprite', 'const char*', 'int')"},
            direction: {
              type: "string",
              enum: ["input", "output", "both"],
              description: "Search direction: 'input' for parameters, 'output' for return types, 'both' for either (default: both)"
            }
          },
          required: ["type"]
        )

        annotations(
          title: TITLE,
          read_only_hint: true,
          destructive_hint: false,
          idempotent_hint: true,
          open_world_hint: false
        )

        def self.call(type:, direction: "both", server_context: {})
          index = server_context[:index]
          return error_response("Index not available") unless index

          pattern = Regexp.new(Regexp.escape(type), Regexp::IGNORECASE)
          input_matches = []
          output_matches = []

          index.functions.each do |func|
            next unless func.signature

            # Check return type (text before function name in signature)
            if direction != "input"
              # Extract return type: everything before the function name
              if func.signature =~ /^(.+?)\s+#{Regexp.escape(func.name)}\s*\(/
                return_type = ::Regexp.last_match(1).strip
                if return_type.match?(pattern)
                  output_matches << func
                end
              end
            end

            # Check input parameters
            if direction != "output"
              # Check the signature for parameter types
              if func.signature =~ /\(([^)]*)\)/
                params_str = ::Regexp.last_match(1)
                if params_str.match?(pattern)
                  input_matches << func unless input_matches.include?(func)
                end
              end
            end
          end

          # Remove duplicates between input and output
          input_matches.uniq!
          output_matches.uniq!

          if input_matches.empty? && output_matches.empty?
            return text_response("No functions found using type '#{type}'")
          end

          lines = ["# Functions using '#{type}'", ""]

          unless input_matches.empty?
            lines << "## Takes as input (#{input_matches.size})"
            input_matches.each do |func|
              lines << "- **#{func.name}** — #{func.brief}"
              lines << "  `#{func.signature}`" if func.signature
            end
            lines << ""
          end

          unless output_matches.empty?
            lines << "## Returns (#{output_matches.size})"
            output_matches.each do |func|
              lines << "- **#{func.name}** — #{func.brief}"
              lines << "  `#{func.signature}`" if func.signature
            end
            lines << ""
          end

          lines << "**Tip:** Use `get_details` with a function name for full documentation."

          text_response(lines.join("\n"))
        end
      end
    end
  end
end
