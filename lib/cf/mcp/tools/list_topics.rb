# frozen_string_literal: true

require "mcp"
require_relative "response_helpers"

module CF
  module MCP
    module Tools
      class ListTopics < ::MCP::Tool
        extend ResponseHelpers

        TITLE = "List Topics"

        tool_name "list_topics"
        title TITLE
        description "List all Cute Framework topic guides, optionally filtered by category or in recommended reading order"

        input_schema(
          type: "object",
          properties: {
            category: {type: "string", description: "Optional: filter topics by category (e.g., 'audio', 'draw', 'graphics')"},
            ordered: {type: "boolean", description: "If true, return topics in recommended reading order (default: false)"}
          }
        )

        annotations(
          title: TITLE,
          read_only_hint: true,
          destructive_hint: false,
          idempotent_hint: true,
          open_world_hint: false
        )

        def self.call(category: nil, ordered: false, server_context: {})
          index = Index.instance

          topics = ordered ? index.topics_ordered : index.topics

          if category
            topics = topics.select { |t| t.category == category }
          end

          if topics.empty?
            return text_response("No topics found#{" in category '#{category}'" if category}\n\n#{CATEGORY_TIP}")
          end

          lines = ["# Cute Framework Topics", ""]

          if ordered
            lines << "_Listed in recommended reading order_"
            lines << ""
          end

          topics.each_with_index do |topic, i|
            prefix = (ordered && topic.reading_order) ? "#{i + 1}. " : "- "
            lines << "#{prefix}**#{topic.name}** — #{topic.brief}"
          end

          lines << ""
          lines << "**Tip:** Use `get_topic` with a topic name to read the full content."

          text_response(lines.join("\n"))
        end

        CATEGORY_TIP = "Use `list_topics` without a category to see all available topics."
      end
    end
  end
end
