# frozen_string_literal: true

require "mcp"
require_relative "response_helpers"

module CF
  module MCP
    module Tools
      class MemberSearch < ::MCP::Tool
        extend ResponseHelpers

        TITLE = "Member Search"

        tool_name "member_search"
        title TITLE
        description "Search Cute Framework structs by member name or type"

        input_schema(
          type: "object",
          properties: {
            query: {type: "string", description: "Search query (matches member name or type in declaration)"},
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

        def self.call(query:, limit: 20, server_context: {})
          index = Index.instance

          pattern = Regexp.new(Regexp.escape(query), Regexp::IGNORECASE)
          results = []

          index.structs.each do |struct|
            next unless struct.members&.any?

            matching_members = struct.members.select { |member|
              member.declaration&.match?(pattern)
            }

            next if matching_members.empty?

            results << {struct: struct, members: matching_members}
            break if results.size >= limit
          end

          if results.empty?
            return text_response("No structs found with members matching '#{query}'")
          end

          lines = ["# Structs with members matching '#{query}'", ""]

          results.each do |result|
            struct = result[:struct]
            lines << "- **#{struct.name}** (#{struct.category}) — #{struct.brief}"
            result[:members].each do |member|
              lines << "  - `#{member.declaration}` — #{member.description}"
            end
            lines << ""
          end

          if results.size >= limit
            lines << "_Results limited to #{limit}. Narrow your search for more specific results._"
            lines << ""
          end

          lines << "**Tip:** Use `get_details` with a struct name for full documentation."

          text_response(lines.join("\n"))
        end
      end
    end
  end
end
