# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "cf/mcp"

# Populate Index.instance with test data before tools are autoloaded
# This ensures tool schemas see test categories
CF::MCP::Index.instance.reset!
CF::MCP::Index.instance.add(CF::MCP::Models::FunctionDoc.new(
  name: "test_func", category: "test", brief: "Test"
))

# Trigger autoload by referencing a tool class
# This loads all tools via autoload with test categories in place
_ = CF::MCP::Tools::SearchTool

require "minitest/autorun"
