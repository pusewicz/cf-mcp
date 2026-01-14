# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::SearchEnumsTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index
  end

  def test_finds_enums
    response = CF::MCP::Tools::SearchEnums.call(query: "direction", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "CF_PlayDirection"
  end

  def test_no_results
    response = CF::MCP::Tools::SearchEnums.call(query: "nonexistent", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "No enums found"
  end

  def test_handles_missing_index
    response = CF::MCP::Tools::SearchEnums.call(query: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_includes_tip
    response = CF::MCP::Tools::SearchEnums.call(query: "direction", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "cf_get_details"
  end
end
