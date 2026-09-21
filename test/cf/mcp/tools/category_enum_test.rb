# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::CategoryEnumTest < Minitest::Test
  include ToolsTestHelper

  TOOLS = [CF::MCP::Tools::SearchTool, CF::MCP::Tools::ListCategory].freeze

  def setup
    setup_test_index
  end

  def teardown
    CF::MCP::Index.instance.reset!
    CF::MCP::Index.instance.add(CF::MCP::Models::FunctionDoc.new(name: "test_func", category: "test", brief: "Test"))
  end

  def test_categories_are_read_when_the_schema_is_asked_for
    TOOLS.each do |tool|
      assert_equal %w[app sprite], category_property(tool)[:enum], tool.tool_name
    end
  end

  def test_the_schema_follows_the_index
    @index.add(CF::MCP::Models::FunctionDoc.new(name: "cf_play_sound", category: "audio", brief: "Plays a sound."))

    TOOLS.each do |tool|
      assert_equal %w[app audio sprite], category_property(tool)[:enum], tool.tool_name
    end
  end

  def test_the_category_is_left_open_while_the_index_is_empty
    @index.reset!

    TOOLS.each do |tool|
      refute category_property(tool).key?(:enum), tool.tool_name
    end
  end

  def test_the_rest_of_the_schema_is_untouched
    schema = CF::MCP::Tools::SearchTool.input_schema.to_h

    assert_equal %w[function struct enum topic], schema.dig(:properties, :type, :enum)
    assert_equal ["query"], schema[:required]
    assert_equal "string", category_property(CF::MCP::Tools::SearchTool)[:type]
  end

  def test_the_server_lists_the_categories
    listed = CF::MCP::Tools::SearchTool.to_h.dig(:inputSchema, :properties, :category, :enum)

    assert_equal %w[app sprite], listed
  end

  private

  def category_property(tool)
    tool.input_schema.to_h.dig(:properties, :category)
  end
end
