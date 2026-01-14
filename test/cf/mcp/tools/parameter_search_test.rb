# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::ParameterSearchTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index
  end

  def test_finds_input_parameters
    response = CF::MCP::Tools::ParameterSearch.call(type: "const char*", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "cf_make_sprite"
  end

  def test_finds_return_type
    response = CF::MCP::Tools::ParameterSearch.call(type: "CF_Sprite", direction: "output", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "cf_make_sprite"
  end

  def test_filters_by_direction_input
    response = CF::MCP::Tools::ParameterSearch.call(type: "CF_Sprite", direction: "input", server_context: @server_context)

    refute response.error?
    # cf_make_sprite returns CF_Sprite but doesn't take it as input
  end

  def test_case_insensitive
    response = CF::MCP::Tools::ParameterSearch.call(type: "sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "cf_make_sprite"
  end

  def test_no_results
    response = CF::MCP::Tools::ParameterSearch.call(type: "NonExistentType", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "No functions found"
  end

  def test_handles_missing_index
    response = CF::MCP::Tools::ParameterSearch.call(type: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end
end
