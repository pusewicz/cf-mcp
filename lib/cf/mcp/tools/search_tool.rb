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

        DETAILS_TIP = "**Tip:** Use `cf_get_details` with an exact name to get full documentation including parameters, examples, and related items."

        def self.call(query:, type: nil, category: nil, limit: 20, server_context: {})
          index = server_context[:index]
          return error_response("Index not available") unless index

          results = index.search(query, type: type, category: category, limit: limit)

          if results.empty?
            text_response("No results found for '#{query}'")
          else
            formatted = results.map(&:to_summary).join("\n")
            header = if results.size >= limit
              "Found #{results.size} result(s) (limit reached, more may exist):"
            else
              "Found #{results.size} result(s):"
            end

            footer = "\n\n#{DETAILS_TIP}"
            footer += "\nTo find more results, narrow your search with `type` or `category` filters." if results.size >= limit

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
