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

  def test_relevance_score_exact_match
    func = CF::MCP::Models::FunctionDoc.new(
      name: "make_app",
      category: "app",
      brief: "Creates an app"
    )

    assert_equal 1000, func.relevance_score("make_app")
    assert_equal 1000, func.relevance_score("MAKE_APP")
  end

  def test_relevance_score_prefix_match
    func = CF::MCP::Models::FunctionDoc.new(
      name: "make_app_window",
      category: "app",
      brief: "Creates an app window"
    )

    assert_equal 500, func.relevance_score("make_app")
  end

  def test_relevance_score_suffix_match
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_app",
      category: "app",
      brief: "Creates an app"
    )

    assert_equal 400, func.relevance_score("make_app")
  end

  def test_relevance_score_contains_in_name
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_app_window",
      category: "app",
      brief: "Creates an app window"
    )

    assert_equal 100, func.relevance_score("make_app")
  end

  def test_relevance_score_match_in_brief_only
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_destroy_app",
      category: "app",
      brief: "Destroys the app created by make_app"
    )

    assert_equal 50, func.relevance_score("make_app")
  end

  def test_relevance_score_match_in_category_only
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_create",
      category: "window_utils",
      brief: "Creates something"
    )

    assert_equal 30, func.relevance_score("window")
  end

  def test_relevance_score_match_in_remarks_only
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_init",
      category: "app",
      brief: "Initializes the framework",
      remarks: "Must be called before make_app"
    )

    assert_equal 10, func.relevance_score("make_app")
  end

  def test_relevance_score_cumulative_scoring
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_app",
      category: "make_app_category",
      brief: "Creates an app using make_app pattern",
      remarks: "See also make_app documentation"
    )

    # suffix match (400) + brief (50) + category (30) + remarks (10)
    assert_equal 490, func.relevance_score("make_app")
  end

  def test_relevance_score_no_match
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_draw_sprite",
      category: "sprite",
      brief: "Draws a sprite"
    )

    assert_equal 0, func.relevance_score("audio")
  end

  def test_relevance_score_empty_query
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_app",
      category: "app",
      brief: "Creates an app"
    )

    assert_equal 0, func.relevance_score("")
    assert_equal 0, func.relevance_score(nil)
  end

  def test_matches_with_multi_keyword_query
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_draw_circle",
      category: "draw",
      brief: "Draws a circle shape"
    )

    # Matches if ANY keyword is found (OR logic)
    assert func.matches?("draw circle")
    assert func.matches?("circle rectangle") # matches "circle"
    assert func.matches?("triangle square circle") # matches "circle"
    refute func.matches?("audio sprite") # neither keyword matches
  end

  def test_relevance_score_multi_keyword
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_draw_circle",
      category: "draw",
      brief: "Draws a circle shape"
    )

    # Single keyword score
    single_score = func.relevance_score("circle")

    # Multi-keyword query sums scores for each keyword
    multi_score = func.relevance_score("draw circle")

    assert multi_score > single_score
  end

  def test_relevance_score_more_keywords_rank_higher
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_draw_circle",
      category: "draw",
      brief: "Draws a circle shape"
    )

    one_keyword = func.relevance_score("circle")
    two_keywords = func.relevance_score("draw circle")

    # More matching keywords = higher score
    assert two_keywords > one_keyword
  end
end
