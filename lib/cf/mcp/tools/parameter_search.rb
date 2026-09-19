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
          index = Index.instance

          pattern = Regexp.new(Regexp.escape(type), Regexp::IGNORECASE)
          functions = index.functions.select(&:signature)

          # Check return type (text before function name in signature)
          output_matches = functions.select { |func|
            next false if direction == "input"

            # Extract return type: everything before the function name
            next false unless func.signature =~ /^(.+?)\s+#{Regexp.escape(func.name)}\s*\(/

            ::Regexp.last_match(1).to_s.strip.match?(pattern)
          }.uniq

          # Check input parameters
          input_matches = functions.select { |func|
            next false if direction == "output"

            # Check the signature for parameter types
            next false unless func.signature =~ /\(([^)]*)\)/

            ::Regexp.last_match(1).to_s.match?(pattern)
          }.uniq

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
