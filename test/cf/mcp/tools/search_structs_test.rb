# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::SearchStructsTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index
  end

  def test_finds_structs
    response = CF::MCP::Tools::SearchStructs.call(query: "sprite", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "CF_Sprite"
    refute_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_no_results
    response = CF::MCP::Tools::SearchStructs.call(query: "nonexistent", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "No structs found"
  end

  def test_handles_missing_index
    response = CF::MCP::Tools::SearchStructs.call(query: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_includes_tip
    response = CF::MCP::Tools::SearchStructs.call(query: "sprite", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "get_details"
  end
end
