# frozen_string_literal: true

require "pathname"
require_relative "mcp/version"
require_relative "mcp/models/doc_item"
require_relative "mcp/models/function_doc"
require_relative "mcp/models/struct_doc"
require_relative "mcp/models/enum_doc"
require_relative "mcp/parser"
require_relative "mcp/index"
require_relative "mcp/index_builder"
require_relative "mcp/server"
require_relative "mcp/downloader"
require_relative "mcp/cli"

module CF
  module MCP
    class Error < StandardError; end

    def self.root
      @root ||= Pathname.new(File.expand_path("../..", __dir__))
    end

    module Tools
      autoload :SearchTool, "cf/mcp/tools/search_tool"
      autoload :ListCategory, "cf/mcp/tools/list_category"
      autoload :GetDetails, "cf/mcp/tools/get_details"
      autoload :FindRelated, "cf/mcp/tools/find_related"
      autoload :ParameterSearch, "cf/mcp/tools/parameter_search"
      autoload :MemberSearch, "cf/mcp/tools/member_search"
      autoload :ListTopics, "cf/mcp/tools/list_topics"
      autoload :GetTopic, "cf/mcp/tools/get_topic"
    end
  end
end
