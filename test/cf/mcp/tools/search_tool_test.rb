# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::SearchToolTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index
  end

  def test_finds_results
    response = CF::MCP::Tools::SearchTool.call(query: "sprite", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "Found"
    assert_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_filters_by_type
    response = CF::MCP::Tools::SearchTool.call(query: "sprite", type: "struct", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "CF_Sprite"
    refute_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_filters_by_category
    response = CF::MCP::Tools::SearchTool.call(query: "make", category: "app", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "cf_make_app"
    refute_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_no_results
    response = CF::MCP::Tools::SearchTool.call(query: "nonexistent", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "No results found"
  end

  def test_handles_missing_index
    response = CF::MCP::Tools::SearchTool.call(query: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_respects_limit_parameter
    response = CF::MCP::Tools::SearchTool.call(query: "sprite", limit: 1, server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "Found 1 result"
  end

  def test_case_insensitive_search
    response = CF::MCP::Tools::SearchTool.call(query: "SPRITE", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "Found"
    assert_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_partial_match
    response = CF::MCP::Tools::SearchTool.call(query: "draw", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "cf_draw_sprite"
  end

  def test_with_type_and_category_filters
    response = CF::MCP::Tools::SearchTool.call(
      query: "sprite",
      type: "function",
      category: "sprite",
      server_context: @server_context
    )

    refute response.error?
    assert_includes response.content.first[:text], "cf_make_sprite"
    refute_includes response.content.first[:text], "(struct)"
  end

  def test_includes_generic_details_tip_without_type_filter
    response = CF::MCP::Tools::SearchTool.call(query: "sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "get_details"
    assert_includes text, "get_topic"
    assert_includes text, "Tip"
  end

  def test_includes_function_specific_tip_with_function_type
    response = CF::MCP::Tools::SearchTool.call(query: "sprite", type: "function", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "signature"
    assert_includes text, "parameters"
    refute_includes text, "get_topic"
  end

  def test_includes_struct_specific_tip_with_struct_type
    response = CF::MCP::Tools::SearchTool.call(query: "sprite", type: "struct", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "members"
    refute_includes text, "get_topic"
  end

  def test_includes_enum_specific_tip_with_enum_type
    response = CF::MCP::Tools::SearchTool.call(query: "direction", type: "enum", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "values"
    refute_includes text, "get_topic"
  end

  def test_shows_type_specific_label_for_functions
    response = CF::MCP::Tools::SearchTool.call(query: "sprite", type: "function", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "function(s)"
  end

  def test_shows_type_specific_label_for_structs
    response = CF::MCP::Tools::SearchTool.call(query: "sprite", type: "struct", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "struct(s)"
  end

  def test_shows_truncation_when_limit_reached
    response = CF::MCP::Tools::SearchTool.call(query: "sprite", limit: 2, server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "limit reached"
    assert_includes text, "more may exist"
    assert_includes text, "narrow your search"
  end

  def test_no_truncation_message_when_under_limit
    response = CF::MCP::Tools::SearchTool.call(query: "app", limit: 20, server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    refute_includes text, "limit reached"
    refute_includes text, "narrow your search"
  end
end
