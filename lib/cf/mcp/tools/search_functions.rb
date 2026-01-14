# frozen_string_literal: true

require "mcp"

module CF
  module MCP
    module Tools
      class SearchFunctions < ::MCP::Tool
        tool_name "cf_search_functions"
        description "Search Cute Framework functions"

        input_schema(
          type: "object",
          properties: {
            query: {type: "string", description: "Search query"},
            category: {type: "string", description: "Optional: filter by category"},
            limit: {type: "integer", description: "Maximum results (default: 20)"}
          },
          required: ["query"]
        )

        def self.call(query:, category: nil, limit: 20, server_context: {})
          index = server_context[:index]
          return error_response("Index not available") unless index

          results = index.search(query, type: :function, category: category, limit: limit)

          if results.empty?
            text_response("No functions found for '#{query}'")
          else
            formatted = results.map { |f| "- **#{f.name}** — #{f.brief}" }.join("\n")
            text_response("Found #{results.size} function(s):\n\n#{formatted}")
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
