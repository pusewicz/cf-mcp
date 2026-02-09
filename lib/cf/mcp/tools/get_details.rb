# frozen_string_literal: true

require_relative "base_tool"

module CF
  module MCP
    module Tools
      class GetDetails < BaseTool
        TITLE = "Get Details"

        tool_name "get_details"
        title TITLE
        description "Get detailed documentation for a specific Cute Framework item by exact name"

        input_schema(
          type: "object",
          properties: {
            name: {type: "string", description: "Exact name of the item (e.g., 'cf_make_app', 'CF_Sprite', 'CF_PlayDirection')"}
          },
          required: ["name"]
        )

        default_annotations(title: TITLE)

        NAMING_TIP = "**Tip:** Cute Framework uses `cf_` prefix for functions and `CF_` prefix for types (structs/enums)."

        def self.call(name:, server_context: {})
          idx = index(server_context)

          item = idx.find(name)

          if item.nil?
            # Try a fuzzy search to suggest alternatives
            suggestions = idx.search(name, limit: 5)
            if suggestions.empty?
              text_response("Not found: '#{name}'\n\n#{NAMING_TIP}")
            else
              formatted = suggestions.map { |s| "- `#{s.name}` (#{s.type}) — #{s.brief}" }.join("\n")
              text_response("Not found: '#{name}'\n\n**Similar items:**\n#{formatted}\n\n#{NAMING_TIP}")
            end
          else
            output = item.to_text(detailed: true, index: idx)

            # Append related topics section for API items
            if item.type != :topic
              related_topics = idx.topics_for(name)
              if related_topics.any?
                output += "\n\n## Related Topics\n"
                output += related_topics.map { |t| "- **#{t.name}** — #{t.brief}" }.join("\n")
                output += "\n\n**Tip:** Use `get_topic` to read the full topic content."
              end
            end

            text_response(output)
          end
        end
      end
    end
  end
end
