# frozen_string_literal: true

require "test_helper"

class CF::MCP::IndexTest < Minitest::Test
  def setup
    @index = CF::MCP::Index.instance
    @index.reset!
    @func = CF::MCP::Models::FunctionDoc.new(
      name: "test_func",
      category: "test",
      brief: "A test function"
    )
    @struct = CF::MCP::Models::StructDoc.new(
      name: "TestStruct",
      category: "test",
      brief: "A test struct"
    )
  end

  def test_add_and_find
    @index.add(@func)
    assert_equal @func, @index.find("test_func")
  end

  def test_search_by_query
    @index.add(@func)
    @index.add(@struct)

    results = @index.search("test")
    assert_equal 2, results.size
  end

  def test_search_by_type
    @index.add(@func)
    @index.add(@struct)

    results = @index.search("test", type: :function)
    assert_equal 1, results.size
    assert_equal @func, results.first
  end

  def test_search_by_category
    other_func = CF::MCP::Models::FunctionDoc.new(
      name: "other_func",
      category: "other",
      brief: "Another function"
    )
    @index.add(@func)
    @index.add(other_func)

    results = @index.search("func", category: "test")
    assert_equal 1, results.size
    assert_equal @func, results.first
  end

  def test_categories
    @index.add(@func)
    assert_includes @index.categories, "test"
  end

  def test_stats
    @index.add(@func)
    @index.add(@struct)

    stats = @index.stats
    assert_equal 2, stats[:total]
    assert_equal 1, stats[:functions]
    assert_equal 1, stats[:structs]
  end

  def test_brief_for_existing_item
    @index.add(@func)

    info = @index.brief_for("test_func")
    assert_equal "test_func", info[:name]
    assert_equal :function, info[:type]
    assert_equal "A test function", info[:brief]
  end

  def test_brief_for_nonexistent_item
    info = @index.brief_for("nonexistent")
    assert_nil info
  end

  def test_search_sorts_by_relevance_exact_match_first
    exact = CF::MCP::Models::FunctionDoc.new(name: "make_app", brief: "Exact match")
    suffix = CF::MCP::Models::FunctionDoc.new(name: "cf_make_app", brief: "Suffix match")
    contains = CF::MCP::Models::FunctionDoc.new(name: "cf_make_app_window", brief: "Contains match")

    @index.add(contains)
    @index.add(exact)
    @index.add(suffix)

    results = @index.search("make_app")

    assert_equal 3, results.size
    assert_equal "make_app", results[0].name
    assert_equal "cf_make_app", results[1].name
    assert_equal "cf_make_app_window", results[2].name
  end

  def test_search_sorts_by_relevance_prefix_before_suffix
    prefix = CF::MCP::Models::FunctionDoc.new(name: "make_app_window", brief: "Prefix match")
    suffix = CF::MCP::Models::FunctionDoc.new(name: "cf_make_app", brief: "Suffix match")

    @index.add(suffix)
    @index.add(prefix)

    results = @index.search("make_app")

    assert_equal 2, results.size
    assert_equal "make_app_window", results[0].name
    assert_equal "cf_make_app", results[1].name
  end

  def test_search_sorts_by_relevance_name_match_before_brief_match
    name_match = CF::MCP::Models::FunctionDoc.new(name: "cf_make_app", brief: "Creates an app")
    brief_match = CF::MCP::Models::FunctionDoc.new(name: "cf_destroy_app", brief: "Destroys the app made by make_app")

    @index.add(brief_match)
    @index.add(name_match)

    results = @index.search("make_app")

    assert_equal 2, results.size
    assert_equal "cf_make_app", results[0].name
    assert_equal "cf_destroy_app", results[1].name
  end

  def test_search_without_query_does_not_sort
    func1 = CF::MCP::Models::FunctionDoc.new(name: "aaa_func", category: "test", brief: "First")
    func2 = CF::MCP::Models::FunctionDoc.new(name: "zzz_func", category: "test", brief: "Second")

    @index.add(func1)
    @index.add(func2)

    results = @index.search(nil)

    assert_equal 2, results.size
    # Order should be insertion order when no query
    assert_equal "aaa_func", results[0].name
    assert_equal "zzz_func", results[1].name
  end

  def test_search_with_empty_query_does_not_sort
    func1 = CF::MCP::Models::FunctionDoc.new(name: "aaa_func", category: "test", brief: "First")
    func2 = CF::MCP::Models::FunctionDoc.new(name: "zzz_func", category: "test", brief: "Second")

    @index.add(func1)
    @index.add(func2)

    results = @index.search("")

    assert_equal 2, results.size
    assert_equal "aaa_func", results[0].name
    assert_equal "zzz_func", results[1].name
  end

  def test_search_relevance_with_type_filter
    func = CF::MCP::Models::FunctionDoc.new(name: "cf_make_app", brief: "Creates an app")
    struct = CF::MCP::Models::StructDoc.new(name: "make_app_config", brief: "Config for app")

    @index.add(struct)
    @index.add(func)

    results = @index.search("make_app", type: :function)

    assert_equal 1, results.size
    assert_equal "cf_make_app", results[0].name
  end

  def test_search_relevance_with_category_filter
    app_func = CF::MCP::Models::FunctionDoc.new(name: "cf_make_app", category: "app", brief: "Creates an app")
    other_func = CF::MCP::Models::FunctionDoc.new(name: "make_app_sprite", category: "sprite", brief: "Makes app sprite")

    @index.add(other_func)
    @index.add(app_func)

    results = @index.search("make_app", category: "app")

    assert_equal 1, results.size
    assert_equal "cf_make_app", results[0].name
  end

  def test_search_with_multi_keyword_query
    draw_circle = CF::MCP::Models::FunctionDoc.new(
      name: "cf_draw_circle",
      category: "draw",
      brief: "Draws a circle"
    )
    draw_rect = CF::MCP::Models::FunctionDoc.new(
      name: "cf_draw_rect",
      category: "draw",
      brief: "Draws a rectangle"
    )
    play_audio = CF::MCP::Models::FunctionDoc.new(
      name: "cf_play_audio",
      category: "audio",
      brief: "Plays audio"
    )

    @index.add(draw_circle)
    @index.add(draw_rect)
    @index.add(play_audio)

    # Multi-keyword query "draw circle" should match both draw functions
    # but rank cf_draw_circle higher (matches both keywords)
    results = @index.search("draw circle")

    assert_equal 2, results.size
    assert_equal "cf_draw_circle", results[0].name
    assert_equal "cf_draw_rect", results[1].name
  end

  def test_search_multi_keyword_ranks_by_match_count
    matches_both = CF::MCP::Models::FunctionDoc.new(
      name: "cf_draw_circle",
      category: "draw",
      brief: "Draws a circle shape"
    )
    matches_one = CF::MCP::Models::FunctionDoc.new(
      name: "cf_draw_rect",
      category: "draw",
      brief: "Draws a rectangle"
    )

    @index.add(matches_one)
    @index.add(matches_both)

    results = @index.search("draw circle")

    # Item matching both keywords should rank higher
    assert_equal "cf_draw_circle", results[0].name
  end
end
