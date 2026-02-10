# frozen_string_literal: true

require "mcp"
require_relative "response_helpers"

module CF
  module MCP
    module Tools
      class ListCategory < ::MCP::Tool
        extend ResponseHelpers

        tool_name "list_category"
        description "List all items in a specific category, or list all available categories"

        input_schema(
          type: "object",
          properties: {
            category: {type: "string", enum: Index.instance.categories, description: "Category name. Leave empty to list all categories."},
            type: {type: "string", enum: ["function", "struct", "enum"], description: "Optional: filter by item type"}
          }
        )

        annotations(
          read_only_hint: true,
          destructive_hint: false,
          idempotent_hint: true,
          open_world_hint: false
        )

        def self.call(category: nil, type: nil, server_context: {})
          index = Index.instance

          if category.nil? || category.empty?
            # List all categories with counts by type
            categories = index.categories
            if categories.empty?
              text_response("No categories found")
            else
              formatted = categories.map do |cat|
                items = index.items_in_category(cat)
                counts = items.group_by(&:type).transform_values(&:size)
                type_breakdown = [:function, :struct, :enum]
                  .filter_map { |t| "#{counts[t]} #{t}s" if counts[t]&.positive? }
                  .join(", ")
                "- **#{cat}** — #{items.size} items (#{type_breakdown})"
              end.join("\n")
              text_response("Available categories:\n\n#{formatted}\n\n**Tip:** Use `list_category` with a category name to see all items in that category.")
            end
          else
            # List items in the specified category
            items = index.items_in_category(category)

            if type
              type_sym = type.to_sym
              items = items.select { |item| item.type == type_sym }
            end

            if items.empty?
              text_response("No items found in category '#{category}'#{" of type #{type}" if type}")
            else
              formatted = items.map(&:to_summary).join("\n")

              # Suggest related topics
              related_topics = index.topics.select { |t| t.category == category }
              topic_suggestion = if related_topics.any?
                "\n\n**Related Topics:**\n" + related_topics.map { |t| "- **#{t.name}** — #{t.brief}" }.join("\n")
              else
                ""
              end

              text_response("Items in '#{category}':\n\n#{formatted}#{topic_suggestion}\n\n**Tip:** Use `get_details` with an exact name to get full documentation.")
            end
          end
        end
      end
    end
  end
end
