# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::MemberSearchTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index
  end

  def test_finds_by_member_name
    response = CF::MCP::Tools::MemberSearch.call(query: "name", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "CF_Sprite"
    assert_includes text, "name"
  end

  def test_finds_by_member_type
    response = CF::MCP::Tools::MemberSearch.call(query: "int", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "CF_Sprite"
  end

  def test_shows_matching_members
    response = CF::MCP::Tools::MemberSearch.call(query: "w", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "int w"
    assert_includes text, "Width in pixels"
  end

  def test_no_results
    response = CF::MCP::Tools::MemberSearch.call(query: "nonexistent_member", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "No structs found"
  end

  def test_respects_limit
    response = CF::MCP::Tools::MemberSearch.call(query: "a", limit: 1, server_context: @server_context)

    refute response.error?
  end
end
