# frozen_string_literal: true

require "mcp"

module CF
  module MCP
    module Tools
      class SearchStructs < ::MCP::Tool
        tool_name "cf_search_structs"
        description "Search Cute Framework structs"

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

          results = index.search(query, type: :struct, category: category, limit: limit)

          if results.empty?
            text_response("No structs found for '#{query}'")
          else
            formatted = results.map { |s| "- **#{s.name}** — #{s.brief}" }.join("\n")
            text_response("Found #{results.size} struct(s):\n\n#{formatted}")
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
