# frozen_string_literal: true

require "mcp"

module CF
  module MCP
    module Tools
      module ResponseHelpers
        def text_response(text)
          ::MCP::Tool::Response.new([{type: "text", text: text}])
        end

        def error_response(message)
          ::MCP::Tool::Response.new([{type: "text", text: "Error: #{message}"}], error: true)
        end
      end
    end
  end
end
