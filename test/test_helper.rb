# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "cf/mcp"

CF::MCP::Index.instance.reset!
CF::MCP::Index.instance.add(CF::MCP::Models::FunctionDoc.new(
  name: "test_func", category: "test", brief: "Test"
))

require "minitest/autorun"
