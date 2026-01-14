# frozen_string_literal: true

require "mcp"

module CF
  module MCP
    module Tools
      class SearchTool < ::MCP::Tool
        tool_name "cf_search"
        description "Search Cute Framework documentation across all types (functions, structs, enums)"

        input_schema(
          type: "object",
          properties: {
            query: {type: "string", description: "Search query (searches in name, description, and remarks)"},
            type: {type: "string", enum: ["function", "struct", "enum"], description: "Optional: filter by item type"},
            category: {type: "string", description: "Optional: filter by category (e.g., 'app', 'sprite', 'graphics')"},
            limit: {type: "integer", description: "Maximum number of results to return (default: 20)"}
          },
          required: ["query"]
        )

        def self.call(query:, type: nil, category: nil, limit: 20, server_context: {})
          index = server_context[:index]
          return error_response("Index not available") unless index

          results = index.search(query, type: type, category: category, limit: limit)

          if results.empty?
            text_response("No results found for '#{query}'")
          else
            formatted = results.map(&:to_summary).join("\n")
            text_response("Found #{results.size} result(s):\n\n#{formatted}")
          end
        end

        def self.text_response(text)
          ::MCP::Tool::Response.new([{type: "text", text: text}])
        end

        def self.error_response(message)
          ::MCP::Tool::Response.new([{type: "text", text: "Error: #{message}"}], error: true)
        end
      end
    end
  end
end
