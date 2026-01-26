# frozen_string_literal: true

require "mcp"
require_relative "response_helpers"
require_relative "search_result_formatter"

module CF
  module MCP
    module Tools
      class SearchTool < ::MCP::Tool
        extend ResponseHelpers
        extend SearchResultFormatter

        TITLE = "CF: Search"

        tool_name "cf_search"
        title TITLE
        description "Search Cute Framework documentation across all types (functions, structs, enums, topics)"

        input_schema(
          type: "object",
          properties: {
            query: {type: "string", description: "Search query (searches in name, description, and remarks)"},
            type: {type: "string", enum: ["function", "struct", "enum", "topic"], description: "Optional: filter by item type"},
            category: {type: "string", description: "Optional: filter by category (e.g., 'app', 'sprite', 'graphics')"},
            limit: {type: "integer", description: "Maximum number of results to return (default: 20)"}
          },
          required: ["query"]
        )

        annotations(
          title: TITLE,
          read_only_hint: true,
          destructive_hint: false,
          idempotent_hint: true,
          open_world_hint: false
        )

        DETAILS_TIP = "**Tip:** Use `cf_get_details` for API items or `cf_get_topic` for topic guides to get full documentation."

        def self.call(query:, type: nil, category: nil, limit: 20, server_context: {})
          index = server_context[:index]
          return error_response("Index not available") unless index

          results = index.search(query, type: type, category: category, limit: limit)

          text = format_search_results(
            results,
            query: query,
            type_label: "result(s)",
            limit: limit,
            details_tip: DETAILS_TIP,
            filter_suggestion: "To find more results, narrow your search with `type` or `category` filters."
          )
          text_response(text)
        end
      end
    end
  end
end
