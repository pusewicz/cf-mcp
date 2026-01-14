# frozen_string_literal: true

require_relative "mcp/version"
require_relative "mcp/models/doc_item"
require_relative "mcp/models/function_doc"
require_relative "mcp/models/struct_doc"
require_relative "mcp/models/enum_doc"
require_relative "mcp/parser"
require_relative "mcp/index"
require_relative "mcp/server"
require_relative "mcp/downloader"
require_relative "mcp/cli"

module CF
  module MCP
    class Error < StandardError; end
  end
end
