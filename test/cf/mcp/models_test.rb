# frozen_string_literal: true

require "test_helper"

class CF::MCP::ModelsTest < Minitest::Test
  def test_function_doc_to_text
    func = CF::MCP::Models::FunctionDoc.new(
      name: "test_func",
      category: "test",
      brief: "A test function",
      signature: "int test_func(void)"
    )

    text = func.to_text(detailed: true)
    assert_includes text, "# test_func"
    assert_includes text, "**Type:** function"
    assert_includes text, "int test_func(void)"
  end

  def test_doc_item_matches_query
    func = CF::MCP::Models::FunctionDoc.new(
      name: "sprite_draw",
      category: "sprite",
      brief: "Draws a sprite on screen"
    )

    assert func.matches?("sprite")
    assert func.matches?("draw")
    assert func.matches?("SPRITE")
    refute func.matches?("audio")
  end
end
