# frozen_string_literal: true

require "mcp"

module CF
  module MCP
    module Tools
      class ListCategory < ::MCP::Tool
        tool_name "cf_list_category"
        description "List all items in a specific category, or list all available categories"

        input_schema(
          type: "object",
          properties: {
            category: {type: "string", description: "Category name (e.g., 'app', 'sprite', 'graphics'). Leave empty to list all categories."},
            type: {type: "string", enum: ["function", "struct", "enum"], description: "Optional: filter by item type"}
          }
        )

        def self.call(category: nil, type: nil, server_context: {})
          index = server_context[:index]
          return error_response("Index not available") unless index

          if category.nil? || category.empty?
            # List all categories with counts
            categories = index.categories
            if categories.empty?
              text_response("No categories found")
            else
              formatted = categories.map do |cat|
                count = index.items_in_category(cat).size
                "- **#{cat}** (#{count} items)"
              end.join("\n")
              text_response("Available categories:\n\n#{formatted}")
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
              text_response("Items in '#{category}':\n\n#{formatted}")
            end
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
