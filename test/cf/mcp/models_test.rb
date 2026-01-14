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

  def test_function_doc_to_summary_includes_signature
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_sprite",
      category: "sprite",
      brief: "Creates a sprite",
      signature: "CF_Sprite cf_make_sprite(const char* path)"
    )

    summary = func.to_summary
    assert_includes summary, "**cf_make_sprite**"
    assert_includes summary, "(function, sprite)"
    assert_includes summary, "Creates a sprite"
    assert_includes summary, "`CF_Sprite cf_make_sprite(const char* path)`"
  end

  def test_function_doc_to_summary_without_signature
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_draw",
      category: "draw",
      brief: "Draws something"
    )

    summary = func.to_summary
    assert_includes summary, "**cf_draw**"
    refute_includes summary, "```"
  end

  def test_struct_doc_to_summary_format
    struct = CF::MCP::Models::StructDoc.new(
      name: "CF_Sprite",
      category: "sprite",
      brief: "A sprite entity"
    )

    summary = struct.to_summary
    assert_includes summary, "**CF_Sprite**"
    assert_includes summary, "(struct, sprite)"
    assert_includes summary, "A sprite entity"
  end

  def test_format_related_items_with_index
    index = CF::MCP::Index.new
    index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_sprite_play",
      category: "sprite",
      brief: "Plays sprite animation"
    ))
    index.add(CF::MCP::Models::StructDoc.new(
      name: "CF_Sprite",
      category: "sprite",
      brief: "A sprite entity"
    ))

    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_sprite",
      category: "sprite",
      brief: "Creates a sprite",
      related: ["cf_sprite_play", "CF_Sprite", "nonexistent_item"]
    )

    formatted = func.format_related_items(index)
    assert_includes formatted, "`cf_sprite_play` (function) — Plays sprite animation"
    assert_includes formatted, "`CF_Sprite` (struct) — A sprite entity"
    assert_includes formatted, "`nonexistent_item`"
    refute_includes formatted, "nonexistent_item` ("
  end

  def test_format_related_items_without_index
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_sprite",
      category: "sprite",
      brief: "Creates a sprite",
      related: ["cf_sprite_play", "CF_Sprite"]
    )

    formatted = func.format_related_items(nil)
    assert_equal "cf_sprite_play, CF_Sprite", formatted
  end

  def test_to_text_includes_enriched_related_items
    index = CF::MCP::Index.new
    index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_sprite_play",
      category: "sprite",
      brief: "Plays sprite animation"
    ))

    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_sprite",
      category: "sprite",
      brief: "Creates a sprite",
      related: ["cf_sprite_play"]
    )

    text = func.to_text(detailed: true, index: index)
    assert_includes text, "## Related"
    assert_includes text, "`cf_sprite_play` (function) — Plays sprite animation"
  end
end
