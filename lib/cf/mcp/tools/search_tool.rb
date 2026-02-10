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

        tool_name "search"
        description "Search Cute Framework documentation across all types (functions, structs, enums, topics)"

        input_schema(
          type: "object",
          properties: {
            query: {type: "string", description: "Search query (searches in name, description, and remarks)"},
            type: {type: "string", enum: ["function", "struct", "enum", "topic"], description: "Optional: filter by item type"},
            category: {type: "string", enum: Index.instance.categories, description: "Optional: filter by category"},
            limit: {type: "integer", description: "Maximum number of results to return (default: 20)"}
          },
          required: ["query"]
        )

        annotations(
          read_only_hint: true,
          destructive_hint: false,
          idempotent_hint: true,
          open_world_hint: false
        )

        DETAILS_TIPS = {
          "function" => "**Tip:** Use `get_details` with an exact name to get full documentation including signature, parameters, and examples.",
          "struct" => "**Tip:** Use `get_details` with an exact name to get full documentation including members and examples.",
          "enum" => "**Tip:** Use `get_details` with an exact name to get full documentation including values and examples.",
          "topic" => "**Tip:** Use `get_topic` with an exact name to get the full topic guide.",
          nil => "**Tip:** Use `get_details` for API items or `get_topic` for topic guides to get full documentation."
        }.freeze

        TYPE_LABELS = {
          "function" => "function(s)",
          "struct" => "struct(s)",
          "enum" => "enum(s)",
          "topic" => "topic(s)",
          nil => "result(s)"
        }.freeze

        def self.call(query:, type: nil, category: nil, limit: 20, server_context: {})
          index = Index.instance

          results = index.search(query, type: type, category: category, limit: limit)

          filter_suggestion = if type
            "To find more results, narrow your search with a `category` filter."
          else
            "To find more results, narrow your search with `type` or `category` filters."
          end

          text = format_search_results(
            results,
            query: query,
            type_label: TYPE_LABELS[type],
            limit: limit,
            details_tip: DETAILS_TIPS[type],
            filter_suggestion: filter_suggestion
          )
          text_response(text)
        end
      end
    end
  end
end
