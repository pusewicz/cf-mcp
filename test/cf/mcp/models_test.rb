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

  def test_source_urls_returns_nil_without_source_file
    func = CF::MCP::Models::FunctionDoc.new(
      name: "test",
      brief: "Test"
    )

    assert_nil func.source_urls
  end

  def test_source_urls_returns_hash_with_source_file
    func = CF::MCP::Models::FunctionDoc.new(
      name: "test",
      brief: "Test",
      source_file: "cute_sprite.h",
      source_line: 42
    )

    urls = func.source_urls

    assert_kind_of Hash, urls
    assert_includes urls[:raw], "cute_sprite.h"
    assert_includes urls[:blob], "cute_sprite.h"
    assert_includes urls[:blob], "#L42"
    assert_includes urls[:impl_raw], "cute_sprite.cpp"
  end

  def test_source_urls_without_source_line
    func = CF::MCP::Models::FunctionDoc.new(
      name: "test",
      brief: "Test",
      source_file: "cute_sprite.h"
    )

    urls = func.source_urls

    refute_includes urls[:blob], "#L"
  end

  def test_to_text_with_source_file_shows_links
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      brief: "Test function",
      category: "test",
      source_file: "cute_test.h",
      source_line: 100
    )

    text = func.to_text(detailed: true)

    assert_includes text, "**Source:**"
    assert_includes text, "cute_test.h"
    assert_includes text, "**Raw:**"
    assert_includes text, "**Implementation:**"
  end

  def test_to_text_with_remarks
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      brief: "Test",
      remarks: "These are important remarks about the function."
    )

    text = func.to_text(detailed: true)

    assert_includes text, "## Remarks"
    assert_includes text, "important remarks"
  end

  def test_to_text_with_example
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      brief: "Test",
      example: "int x = 42;",
      example_brief: "Simple example usage"
    )

    text = func.to_text(detailed: true)

    assert_includes text, "## Example"
    assert_includes text, "Simple example usage"
    assert_includes text, "```c"
    assert_includes text, "int x = 42;"
    assert_includes text, "```"
  end

  def test_to_text_with_example_no_brief
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      brief: "Test",
      example: "int x = 42;"
    )

    text = func.to_text(detailed: true)

    assert_includes text, "## Example"
    assert_includes text, "int x = 42;"
  end

  def test_struct_to_h
    struct = CF::MCP::Models::StructDoc.new(
      name: "CF_Test",
      brief: "Test struct",
      members: [
        CF::MCP::Models::StructDoc::Member.new("int x", "X coordinate")
      ]
    )

    hash = struct.to_h

    assert_equal "CF_Test", hash[:name]
    assert_equal 1, hash[:members].size
    assert_equal "int x", hash[:members].first[:declaration]
    assert_equal "X coordinate", hash[:members].first[:description]
  end

  def test_struct_to_text_with_members
    struct = CF::MCP::Models::StructDoc.new(
      name: "CF_Test",
      brief: "Test struct",
      members: [
        CF::MCP::Models::StructDoc::Member.new("int x", "X coordinate"),
        CF::MCP::Models::StructDoc::Member.new("int y", "Y coordinate")
      ]
    )

    text = struct.to_text(detailed: true)

    assert_includes text, "## Members"
    assert_includes text, "| `int x` | X coordinate |"
    assert_includes text, "| `int y` | Y coordinate |"
  end

  def test_struct_to_text_without_members
    struct = CF::MCP::Models::StructDoc.new(
      name: "CF_Test",
      brief: "Test struct",
      members: []
    )

    text = struct.to_text(detailed: true)

    refute_includes text, "## Members"
  end

  def test_enum_to_h
    enum = CF::MCP::Models::EnumDoc.new(
      name: "CF_Test",
      brief: "Test enum",
      entries: [
        CF::MCP::Models::EnumDoc::Entry.new("VALUE_ONE", "0", "First value")
      ]
    )

    hash = enum.to_h

    assert_equal "CF_Test", hash[:name]
    assert_equal 1, hash[:entries].size
    assert_equal "VALUE_ONE", hash[:entries].first[:name]
  end

  def test_enum_to_text_with_entries
    enum = CF::MCP::Models::EnumDoc.new(
      name: "CF_Test",
      brief: "Test enum",
      entries: [
        CF::MCP::Models::EnumDoc::Entry.new("VALUE_ONE", "0", "First value"),
        CF::MCP::Models::EnumDoc::Entry.new("VALUE_TWO", "1", "Second value")
      ]
    )

    text = enum.to_text(detailed: true)

    assert_includes text, "## Values"
    assert_includes text, "| `VALUE_ONE` | 0 | First value |"
    assert_includes text, "| `VALUE_TWO` | 1 | Second value |"
  end

  def test_enum_to_text_without_entries
    enum = CF::MCP::Models::EnumDoc.new(
      name: "CF_Test",
      brief: "Test enum",
      entries: []
    )

    text = enum.to_text(detailed: true)

    refute_includes text, "## Values"
  end

  def test_function_to_h
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      brief: "Test function",
      signature: "void cf_test(int x)",
      parameters: [
        CF::MCP::Models::FunctionDoc::Parameter.new("x", "Input value")
      ],
      return_value: "Returns nothing"
    )

    hash = func.to_h

    assert_equal "cf_test", hash[:name]
    assert_equal "void cf_test(int x)", hash[:signature]
    assert_equal 1, hash[:parameters].size
    assert_equal "Returns nothing", hash[:return_value]
  end

  def test_function_to_text_with_return_value
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      brief: "Test function",
      return_value: "Returns a value"
    )

    text = func.to_text(detailed: true)

    assert_includes text, "## Return Value"
    assert_includes text, "Returns a value"
  end

  def test_function_to_text_without_return_value
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      brief: "Test function"
    )

    text = func.to_text(detailed: true)

    refute_includes text, "## Return Value"
  end

  def test_function_to_text_without_parameters
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      brief: "Test function",
      parameters: []
    )

    text = func.to_text(detailed: true)

    refute_includes text, "## Parameters"
  end

  def test_function_to_text_without_signature
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      brief: "Test function"
    )

    text = func.to_text(detailed: true)

    refute_includes text, "## Signature"
  end

  def test_doc_item_to_h
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      category: "test",
      brief: "Test brief",
      remarks: "Remarks here",
      example: "example code",
      example_brief: "Example brief",
      related: ["other_func"],
      source_file: "cute.h",
      source_line: 42
    )

    hash = func.to_h

    assert_equal "cf_test", hash[:name]
    assert_equal :function, hash[:type]
    assert_equal "test", hash[:category]
    assert_equal "Test brief", hash[:brief]
    assert_equal "Remarks here", hash[:remarks]
    assert_equal "example code", hash[:example]
    assert_equal "Example brief", hash[:example_brief]
    assert_equal ["other_func"], hash[:related]
    assert_equal "cute.h", hash[:source_file]
    assert_equal 42, hash[:source_line]
  end

  def test_doc_item_matches_empty_query_returns_true
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      brief: "Test"
    )

    assert func.matches?(nil)
    assert func.matches?("")
    assert func.matches?("   ")
  end

  def test_doc_item_to_text_without_category
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      brief: "Test"
    )

    text = func.to_text(detailed: false)

    refute_includes text, "**Category:**"
  end

  def test_build_related_lines_with_empty_related
    func = CF::MCP::Models::FunctionDoc.new(
      name: "cf_test",
      brief: "Test",
      related: []
    )

    text = func.to_text(detailed: true)

    refute_includes text, "## Related"
  end

  def test_build_type_specific_lines_base_class
    # Create a minimal DocItem subclass to test the base implementation
    test_doc_class = Class.new(CF::MCP::Models::DocItem) do
      def initialize
        super(type: :test, name: "test", brief: "Test")
      end
    end
    test_doc = test_doc_class.new

    # Call the base class method directly (not overridden in our anonymous class)
    result = test_doc.send(:build_type_specific_lines)

    assert_equal [], result
  end
end
