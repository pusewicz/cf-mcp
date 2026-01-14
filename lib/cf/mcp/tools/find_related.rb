# frozen_string_literal: true

require "mcp"
require_relative "response_helpers"

module CF
  module MCP
    module Tools
      class FindRelated < ::MCP::Tool
        extend ResponseHelpers

        tool_name "cf_find_related"
        description "Find all items related to a given Cute Framework item (bidirectional relationship search)"

        input_schema(
          type: "object",
          properties: {
            name: {type: "string", description: "Name of the item to find relations for (e.g., 'CF_Sprite', 'cf_make_sprite')"}
          },
          required: ["name"]
        )

        def self.call(name:, server_context: {})
          index = server_context[:index]
          return error_response("Index not available") unless index

          item = index.find(name)
          return text_response("Not found: '#{name}'") unless item

          # Forward references: items this item references
          forward_refs = (item.related || []).map { |ref_name|
            ref_item = index.find(ref_name)
            if ref_item
              "- `#{ref_item.name}` (#{ref_item.type}) — #{ref_item.brief}"
            else
              "- `#{ref_name}` (not found in index)"
            end
          }

          # Back references: items that reference this item
          back_refs = []
          index.items.each_value do |other_item|
            next if other_item.name == name
            next unless other_item.related&.include?(name)

            back_refs << "- `#{other_item.name}` (#{other_item.type}) — #{other_item.brief}"
          end

          if forward_refs.empty? && back_refs.empty?
            return text_response("# #{name}\n\nNo related items found.\n\n**Tip:** Not all items have explicit relationships documented.")
          end

          lines = ["# Related items for #{name}", ""]

          unless forward_refs.empty?
            lines << "## References (items this references)"
            lines.concat(forward_refs)
            lines << ""
          end

          unless back_refs.empty?
            lines << "## Referenced by (items that reference this)"
            lines.concat(back_refs)
            lines << ""
          end

          text_response(lines.join("\n"))
        end
      end
    end
  end
end
