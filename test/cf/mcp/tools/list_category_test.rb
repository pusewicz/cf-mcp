# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::ListCategoryTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index
  end

  def test_lists_all_categories
    response = CF::MCP::Tools::ListCategory.call(server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "sprite"
    assert_includes response.content.first[:text], "app"
  end

  def test_lists_items_in_category
    response = CF::MCP::Tools::ListCategory.call(category: "sprite", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "cf_make_sprite"
    assert_includes response.content.first[:text], "CF_Sprite"
    refute_includes response.content.first[:text], "cf_make_app"
  end

  def test_filters_by_type
    response = CF::MCP::Tools::ListCategory.call(category: "sprite", type: "function", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "cf_make_sprite"
    refute_includes response.content.first[:text], "(struct)"
  end

  def test_nonexistent_category
    response = CF::MCP::Tools::ListCategory.call(category: "nonexistent", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "No items found"
  end

  def test_empty_category_string
    response = CF::MCP::Tools::ListCategory.call(category: "", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "Available categories"
  end

  def test_with_struct_type_filter
    response = CF::MCP::Tools::ListCategory.call(
      category: "sprite",
      type: "struct",
      server_context: @server_context
    )

    refute response.error?
    assert_includes response.content.first[:text], "CF_Sprite"
    refute_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_with_enum_type_filter
    response = CF::MCP::Tools::ListCategory.call(
      category: "sprite",
      type: "enum",
      server_context: @server_context
    )

    refute response.error?
    assert_includes response.content.first[:text], "CF_PlayDirection"
    refute_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_shows_type_breakdown
    response = CF::MCP::Tools::ListCategory.call(server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "sprite"
    assert_includes text, "functions"
    assert_includes text, "struct"
    assert_includes text, "enum"
  end

  def test_items_includes_tip
    response = CF::MCP::Tools::ListCategory.call(category: "sprite", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "get_details"
    assert_includes response.content.first[:text], "Tip"
  end
end
