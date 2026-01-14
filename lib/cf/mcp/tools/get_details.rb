# frozen_string_literal: true

require "mcp"

module CF
  module MCP
    module Tools
      class GetDetails < ::MCP::Tool
        tool_name "cf_get_details"
        description "Get detailed documentation for a specific Cute Framework item by exact name"

        input_schema(
          type: "object",
          properties: {
            name: {type: "string", description: "Exact name of the item (e.g., 'cf_make_app', 'CF_Sprite', 'CF_PlayDirection')"}
          },
          required: ["name"]
        )

        def self.call(name:, server_context: {})
          index = server_context[:index]
          return error_response("Index not available") unless index

          item = index.find(name)

          if item.nil?
            # Try a fuzzy search to suggest alternatives
            suggestions = index.search(name, limit: 5)
            if suggestions.empty?
              text_response("Not found: '#{name}'")
            else
              names = suggestions.map(&:name).join(", ")
              text_response("Not found: '#{name}'\n\nDid you mean: #{names}?")
            end
          else
            text_response(item.to_text(detailed: true))
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
