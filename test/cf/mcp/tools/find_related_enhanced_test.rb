# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::FindRelatedEnhancedTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index_with_topics
  end

  def test_finds_forward_references
    response = CF::MCP::Tools::FindRelated.call(name: "cf_make_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "References"
    assert_includes text, "CF_Sprite"
    assert_includes text, "cf_draw_sprite"
  end

  def test_shows_not_found_in_index_for_missing_refs
    response = CF::MCP::Tools::FindRelated.call(name: "cf_make_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "nonexistent_item"
    assert_includes text, "not found in index"
  end

  def test_finds_back_references
    response = CF::MCP::Tools::FindRelated.call(name: "cf_make_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Referenced by"
    assert_includes text, "cf_draw_sprite"
  end

  def test_no_related_items
    response = CF::MCP::Tools::FindRelated.call(name: "cf_no_related", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "No related items found"
    assert_includes text, "Tip"
  end

  def test_not_found
    response = CF::MCP::Tools::FindRelated.call(name: "nonexistent", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Not found"
  end

  def test_handles_missing_index
    response = CF::MCP::Tools::FindRelated.call(name: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_item_with_only_back_references
    # CF_Sprite has no forward refs but is referenced by cf_make_sprite
    response = CF::MCP::Tools::FindRelated.call(name: "CF_Sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Referenced by"
    assert_includes text, "cf_make_sprite"
  end
end
