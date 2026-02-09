# frozen_string_literal: true

require "mcp"
require_relative "response_helpers"

module CF
  module MCP
    module Tools
      class BaseTool < ::MCP::Tool
        extend ResponseHelpers

        def self.default_annotations(title:)
          annotations(
            title: title,
            read_only_hint: true,
            destructive_hint: false,
            idempotent_hint: true,
            open_world_hint: false
          )
        end

        def self.index(server_context)
          server_context[:index] || Index.instance
        end
      end
    end
  end
end
