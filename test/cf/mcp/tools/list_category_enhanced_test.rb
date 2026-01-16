# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::ListCategoryEnhancedTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index_with_topics
  end

  def test_list_all_categories
    response = CF::MCP::Tools::ListCategory.call(server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Available categories"
    assert_includes text, "sprite"
    assert_includes text, "app"
    assert_includes text, "items"
  end

  def test_list_category_shows_type_breakdown
    response = CF::MCP::Tools::ListCategory.call(server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "functions"
    assert_includes text, "structs"
    assert_includes text, "enums"
  end

  def test_list_specific_category
    response = CF::MCP::Tools::ListCategory.call(category: "sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Items in 'sprite'"
    assert_includes text, "cf_make_sprite"
    assert_includes text, "CF_Sprite"
  end

  def test_list_category_with_type_filter
    response = CF::MCP::Tools::ListCategory.call(category: "sprite", type: "function", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "cf_make_sprite"
    # CF_Sprite may appear in related topics, so just check functions are listed
    assert_includes text, "function"
  end

  def test_list_category_shows_related_topics
    response = CF::MCP::Tools::ListCategory.call(category: "sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Related Topics"
    assert_includes text, "sprite_guide"
  end

  def test_list_empty_category
    response = CF::MCP::Tools::ListCategory.call(category: "nonexistent", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "No items found"
    assert_includes text, "nonexistent"
  end

  def test_list_category_with_type_no_matches
    # Use a category that has no enums
    response = CF::MCP::Tools::ListCategory.call(category: "app", type: "enum", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "No items found"
    assert_includes text, "type enum"
  end

  def test_empty_index_no_categories
    empty_index = CF::MCP::Index.new
    response = CF::MCP::Tools::ListCategory.call(server_context: {index: empty_index})

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "No categories found"
  end

  def test_handles_missing_index
    response = CF::MCP::Tools::ListCategory.call(server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_category_with_no_related_topics
    response = CF::MCP::Tools::ListCategory.call(category: "misc", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    # misc category has no related topics
    refute_includes text, "Related Topics"
  end
end
