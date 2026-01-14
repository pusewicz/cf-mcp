# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::GetDetailsTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index
  end

  def test_finds_function
    response = CF::MCP::Tools::GetDetails.call(name: "cf_make_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "# cf_make_sprite"
    assert_includes text, "Loads a sprite"
    assert_includes text, "CF_Sprite cf_make_sprite"
    assert_includes text, "## Parameters"
    assert_includes text, "## Return Value"
  end

  def test_finds_struct
    response = CF::MCP::Tools::GetDetails.call(name: "CF_Sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "# CF_Sprite"
    assert_includes text, "drawable entity"
  end

  def test_finds_enum
    response = CF::MCP::Tools::GetDetails.call(name: "CF_PlayDirection", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "# CF_PlayDirection"
    assert_includes text, "direction"
  end

  def test_not_found_suggests_alternatives
    response = CF::MCP::Tools::GetDetails.call(name: "cf_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Not found"
    assert_includes text, "Similar items"
  end

  def test_completely_not_found
    empty_index = CF::MCP::Index.new
    response = CF::MCP::Tools::GetDetails.call(name: "nonexistent", server_context: {index: empty_index})

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Not found"
    refute_includes text, "Similar items"
  end

  def test_handles_missing_index
    response = CF::MCP::Tools::GetDetails.call(name: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_includes_naming_tip_on_not_found
    response = CF::MCP::Tools::GetDetails.call(name: "nonexistent", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "cf_"
    assert_includes text, "CF_"
    assert_includes text, "prefix"
  end

  def test_enriches_related_items
    response = CF::MCP::Tools::GetDetails.call(name: "cf_make_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "## Related"
    assert_includes text, "(struct)"
    assert_includes text, "(function)"
  end
end
