# frozen_string_literal: true

require "mcp"
require_relative "response_helpers"
require_relative "search_result_formatter"

module CF
  module MCP
    module Tools
      class SearchStructs < ::MCP::Tool
        extend ResponseHelpers
        extend SearchResultFormatter

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

        DETAILS_TIP = "**Tip:** Use `cf_get_details` with an exact name to get full documentation including members and examples."

        def self.call(query:, category: nil, limit: 20, server_context: {})
          index = server_context[:index]
          return error_response("Index not available") unless index

          results = index.search(query, type: :struct, category: category, limit: limit)

          text = format_search_results(
            results,
            query: query,
            type_label: "struct(s)",
            limit: limit,
            details_tip: DETAILS_TIP,
            filter_suggestion: "To find more results, narrow your search with a `category` filter."
          )
          text_response(text)
        end
      end
    end
  end
end
