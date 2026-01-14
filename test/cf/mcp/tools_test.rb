# frozen_string_literal: true

require "test_helper"

class CF::MCP::ToolsTest < Minitest::Test
  def setup
    @index = CF::MCP::Index.new
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_sprite",
      category: "sprite",
      brief: "Loads a sprite from an aseprite file.",
      signature: "CF_Sprite cf_make_sprite(const char* path)",
      parameters: [
        CF::MCP::Models::FunctionDoc::Parameter.new("path", "Path to the .ase file")
      ],
      return_value: "Returns a CF_Sprite",
      related: ["CF_Sprite", "cf_draw_sprite"]
    ))
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_draw_sprite",
      category: "sprite",
      brief: "Draws a sprite on screen."
    ))
    @index.add(CF::MCP::Models::StructDoc.new(
      name: "CF_Sprite",
      category: "sprite",
      brief: "A sprite represents a drawable entity.",
      members: [
        CF::MCP::Models::StructDoc::Member.new("const char* name", "The sprite name"),
        CF::MCP::Models::StructDoc::Member.new("int w", "Width in pixels")
      ]
    ))
    @index.add(CF::MCP::Models::EnumDoc.new(
      name: "CF_PlayDirection",
      category: "sprite",
      brief: "The direction a sprite plays frames.",
      entries: [
        CF::MCP::Models::EnumDoc::Entry.new("PLAY_DIRECTION_FORWARDS", "0", "Play forwards"),
        CF::MCP::Models::EnumDoc::Entry.new("PLAY_DIRECTION_BACKWARDS", "1", "Play backwards")
      ]
    ))
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_app",
      category: "app",
      brief: "Creates an application window."
    ))

    @server_context = {index: @index}
  end

  def test_search_tool_finds_results
    response = CF::MCP::Tools::SearchTool.call(query: "sprite", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "Found"
    assert_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_search_tool_filters_by_type
    response = CF::MCP::Tools::SearchTool.call(query: "sprite", type: "struct", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "CF_Sprite"
    refute_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_search_tool_filters_by_category
    response = CF::MCP::Tools::SearchTool.call(query: "make", category: "app", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "cf_make_app"
    refute_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_search_tool_no_results
    response = CF::MCP::Tools::SearchTool.call(query: "nonexistent", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "No results found"
  end

  def test_search_functions_tool
    response = CF::MCP::Tools::SearchFunctions.call(query: "sprite", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "cf_make_sprite"
    assert_includes response.content.first[:text], "cf_draw_sprite"
    refute_includes response.content.first[:text], "CF_Sprite"
  end

  def test_search_structs_tool
    response = CF::MCP::Tools::SearchStructs.call(query: "sprite", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "CF_Sprite"
    refute_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_search_enums_tool
    response = CF::MCP::Tools::SearchEnums.call(query: "direction", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "CF_PlayDirection"
  end

  def test_list_category_lists_all_categories
    response = CF::MCP::Tools::ListCategory.call(server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "sprite"
    assert_includes response.content.first[:text], "app"
  end

  def test_list_category_lists_items_in_category
    response = CF::MCP::Tools::ListCategory.call(category: "sprite", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "cf_make_sprite"
    assert_includes response.content.first[:text], "CF_Sprite"
    refute_includes response.content.first[:text], "cf_make_app"
  end

  def test_list_category_filters_by_type
    response = CF::MCP::Tools::ListCategory.call(category: "sprite", type: "function", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "cf_make_sprite"
    refute_includes response.content.first[:text], "CF_Sprite"
  end

  def test_get_details_finds_item
    response = CF::MCP::Tools::GetDetails.call(name: "cf_make_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "# cf_make_sprite"
    assert_includes text, "Loads a sprite"
    assert_includes text, "CF_Sprite cf_make_sprite"
    assert_includes text, "## Parameters"
    assert_includes text, "## Return Value"
  end

  def test_get_details_not_found_suggests_alternatives
    response = CF::MCP::Tools::GetDetails.call(name: "cf_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Not found"
    assert_includes text, "Did you mean"
  end

  def test_tools_handle_missing_index
    response = CF::MCP::Tools::SearchTool.call(query: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  # Additional edge case tests

  def test_search_tool_respects_limit_parameter
    response = CF::MCP::Tools::SearchTool.call(query: "sprite", limit: 1, server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "Found 1 result"
  end

  def test_search_tool_case_insensitive_search
    response = CF::MCP::Tools::SearchTool.call(query: "SPRITE", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "Found"
    assert_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_search_tool_partial_match
    response = CF::MCP::Tools::SearchTool.call(query: "draw", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "cf_draw_sprite"
  end

  def test_search_functions_no_results
    response = CF::MCP::Tools::SearchFunctions.call(query: "nonexistent", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "No functions found"
  end

  def test_search_structs_no_results
    response = CF::MCP::Tools::SearchStructs.call(query: "nonexistent", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "No structs found"
  end

  def test_search_enums_no_results
    response = CF::MCP::Tools::SearchEnums.call(query: "nonexistent", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "No enums found"
  end

  def test_list_category_nonexistent_category
    response = CF::MCP::Tools::ListCategory.call(category: "nonexistent", server_context: @server_context)

    refute response.error?
    assert_includes response.content.first[:text], "No items found"
  end

  def test_list_category_empty_category_string
    response = CF::MCP::Tools::ListCategory.call(category: "", server_context: @server_context)

    refute response.error?
    # Empty string should list all categories
    assert_includes response.content.first[:text], "Available categories"
  end

  def test_get_details_finds_struct
    response = CF::MCP::Tools::GetDetails.call(name: "CF_Sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "# CF_Sprite"
    assert_includes text, "drawable entity"
  end

  def test_get_details_finds_enum
    response = CF::MCP::Tools::GetDetails.call(name: "CF_PlayDirection", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "# CF_PlayDirection"
    assert_includes text, "direction"
  end

  def test_get_details_completely_not_found
    # Create an empty index to test the "no suggestions" path
    empty_index = CF::MCP::Index.new
    response = CF::MCP::Tools::GetDetails.call(name: "nonexistent", server_context: {index: empty_index})

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Not found"
    refute_includes text, "Did you mean"
  end

  def test_search_functions_handles_missing_index
    response = CF::MCP::Tools::SearchFunctions.call(query: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_search_structs_handles_missing_index
    response = CF::MCP::Tools::SearchStructs.call(query: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_search_enums_handles_missing_index
    response = CF::MCP::Tools::SearchEnums.call(query: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_list_category_handles_missing_index
    response = CF::MCP::Tools::ListCategory.call(server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_get_details_handles_missing_index
    response = CF::MCP::Tools::GetDetails.call(name: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_search_tool_with_type_and_category_filters
    response = CF::MCP::Tools::SearchTool.call(
      query: "sprite",
      type: "function",
      category: "sprite",
      server_context: @server_context
    )

    refute response.error?
    assert_includes response.content.first[:text], "cf_make_sprite"
    refute_includes response.content.first[:text], "CF_Sprite"
  end

  def test_search_functions_with_category_filter
    response = CF::MCP::Tools::SearchFunctions.call(
      query: "make",
      category: "sprite",
      server_context: @server_context
    )

    refute response.error?
    assert_includes response.content.first[:text], "cf_make_sprite"
    refute_includes response.content.first[:text], "cf_make_app"
  end

  def test_list_category_with_struct_type_filter
    response = CF::MCP::Tools::ListCategory.call(
      category: "sprite",
      type: "struct",
      server_context: @server_context
    )

    refute response.error?
    assert_includes response.content.first[:text], "CF_Sprite"
    refute_includes response.content.first[:text], "cf_make_sprite"
  end

  def test_list_category_with_enum_type_filter
    response = CF::MCP::Tools::ListCategory.call(
      category: "sprite",
      type: "enum",
      server_context: @server_context
    )

    refute response.error?
    assert_includes response.content.first[:text], "CF_PlayDirection"
    refute_includes response.content.first[:text], "cf_make_sprite"
  end
end
