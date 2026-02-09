# frozen_string_literal: true

require_relative "base_tool"

module CF
  module MCP
    module Tools
      class GetTopic < BaseTool
        TITLE = "Get Topic"

        tool_name "get_topic"
        title TITLE
        description "Get the full content of a Cute Framework topic guide document"

        input_schema(
          type: "object",
          properties: {
            name: {type: "string", description: "Topic name (e.g., 'audio', 'collision', 'drawing', 'coroutines')"}
          },
          required: ["name"]
        )

        default_annotations(title: TITLE)

        def self.call(name:, server_context: {})
          idx = index(server_context)

          topic = idx.find(name)

          if topic.nil? || topic.type != :topic
            # Try fuzzy match on topic names
            suggestions = idx.topics.select { |t|
              t.name.include?(name) || name.include?(t.name) || t.name.delete("_").include?(name.delete("_"))
            }

            if suggestions.empty?
              text_response("Topic not found: '#{name}'\n\nUse `list_topics` to see available topics.")
            else
              formatted = suggestions.map { |t| "- **#{t.name}** — #{t.brief}" }.join("\n")
              text_response("Topic not found: '#{name}'\n\n**Similar topics:**\n#{formatted}")
            end
          else
            text_response(topic.to_text(detailed: true, index: idx))
          end
        end
      end
    end
  end
end
