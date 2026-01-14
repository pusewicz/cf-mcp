# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::SearchFunctionsTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index
  end

  def test_finds_functions
    response = CF::MCP::Tools::SearchFunctions.call(query: "sprite", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "cf_make_sprite"
    assert_includes response.content.first[:text], "cf_draw_sprite"
    refute_includes response.content.first[:text], "(struct)"
  end

  def test_no_results
    response = CF::MCP::Tools::SearchFunctions.call(query: "nonexistent", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "No functions found"
  end

  def test_handles_missing_index
    response = CF::MCP::Tools::SearchFunctions.call(query: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_with_category_filter
    response = CF::MCP::Tools::SearchFunctions.call(
      query: "make",
      category: "sprite",
      server_context: @server_context
    )

    refute response.error?
    assert_includes response.content.first[:text], "cf_make_sprite"
    refute_includes response.content.first[:text], "cf_make_app"
  end

  def test_includes_signature_in_summary
    response = CF::MCP::Tools::SearchFunctions.call(query: "make_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "CF_Sprite cf_make_sprite(const char* path)"
  end

  def test_shows_truncation_when_limit_reached
    response = CF::MCP::Tools::SearchFunctions.call(query: "sprite", limit: 1, server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "limit reached"
    assert_includes text, "category"
  end
end
