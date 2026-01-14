# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::FindRelatedTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index
  end

  def test_finds_forward_references
    response = CF::MCP::Tools::FindRelated.call(name: "cf_make_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "cf_make_sprite"
    assert_includes text, "CF_Sprite"
    assert_includes text, "cf_draw_sprite"
  end

  def test_finds_back_references
    response = CF::MCP::Tools::FindRelated.call(name: "CF_Sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Referenced by"
    assert_includes text, "cf_make_sprite"
  end

  def test_not_found
    response = CF::MCP::Tools::FindRelated.call(name: "nonexistent", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Not found"
  end

  def test_no_relations
    response = CF::MCP::Tools::FindRelated.call(name: "cf_make_app", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "No related items"
  end

  def test_handles_missing_index
    response = CF::MCP::Tools::FindRelated.call(name: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end
end
