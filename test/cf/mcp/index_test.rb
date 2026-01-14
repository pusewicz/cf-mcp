# frozen_string_literal: true

require "test_helper"

class CF::MCP::IndexTest < Minitest::Test
  def setup
    @index = CF::MCP::Index.new
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
end
