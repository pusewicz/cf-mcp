# frozen_string_literal: true

require "mcp"

module CF
  module MCP
    module Tools
      class GetTopic < ::MCP::Tool
        tool_name "cf_get_topic"
        description "Get the full content of a Cute Framework topic guide document"

        input_schema(
          type: "object",
          properties: {
            name: {type: "string", description: "Topic name (e.g., 'audio', 'collision', 'drawing', 'coroutines')"}
          },
          required: ["name"]
        )

        def self.call(name:, server_context: {})
          index = server_context[:index]
          return error_response("Index not available") unless index

          topic = index.find(name)

          if topic.nil? || topic.type != :topic
            # Try fuzzy match on topic names
            suggestions = index.topics.select { |t|
              t.name.include?(name) || name.include?(t.name) || t.name.delete("_").include?(name.delete("_"))
            }

            if suggestions.empty?
              text_response("Topic not found: '#{name}'\n\nUse `cf_list_topics` to see available topics.")
            else
              formatted = suggestions.map { |t| "- **#{t.name}** — #{t.brief}" }.join("\n")
              text_response("Topic not found: '#{name}'\n\n**Similar topics:**\n#{formatted}")
            end
          else
            text_response(topic.to_text(detailed: true, index: index))
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
