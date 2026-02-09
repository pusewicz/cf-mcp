# frozen_string_literal: true

require "pathname"
require_relative "mcp/version"

module CF
  module MCP
    class Error < StandardError; end

    autoload :Parser, "cf/mcp/parser"
    autoload :Index, "cf/mcp/index"
    autoload :IndexBuilder, "cf/mcp/index_builder"
    autoload :TopicParser, "cf/mcp/topic_parser"
    autoload :Server, "cf/mcp/server"
    autoload :Downloader, "cf/mcp/downloader"
    autoload :GitHubClient, "cf/mcp/github_client"
    autoload :CLI, "cf/mcp/cli"

    def self.root
      @root ||= Pathname.new(File.expand_path("../..", __dir__))
    end

    module Models
      autoload :DocItem, "cf/mcp/models/doc_item"
      autoload :FunctionDoc, "cf/mcp/models/function_doc"
      autoload :StructDoc, "cf/mcp/models/struct_doc"
      autoload :EnumDoc, "cf/mcp/models/enum_doc"
      autoload :TopicDoc, "cf/mcp/models/topic_doc"
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
