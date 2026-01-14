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

        DETAILS_TIP = "**Tip:** Use `cf_get_details` with an exact name to get full documentation including signature, parameters, and examples."

        def self.call(query:, category: nil, limit: 20, server_context: {})
          index = server_context[:index]
          return error_response("Index not available") unless index

          results = index.search(query, type: :function, category: category, limit: limit)

          if results.empty?
            text_response("No functions found for '#{query}'")
          else
            formatted = results.map(&:to_summary).join("\n")
            header = if results.size >= limit
              "Found #{results.size} function(s) (limit reached, more may exist):"
            else
              "Found #{results.size} function(s):"
            end

            footer = "\n\n#{DETAILS_TIP}"
            footer += "\nTo find more results, narrow your search with a `category` filter." if results.size >= limit

            text_response("#{header}\n\n#{formatted}#{footer}")
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
