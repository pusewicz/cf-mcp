# frozen_string_literal: true

require "test_helper"

class CF::MCP::ParserTest < Minitest::Test
  def setup
    @parser = CF::MCP::Parser.new
    @fixture_path = File.expand_path("../../fixtures/sample_header.h", __dir__)
  end

  def test_parse_file_returns_array
    items = @parser.parse_file(@fixture_path)
    assert_kind_of Array, items
  end

  def test_parse_file_extracts_struct
    items = @parser.parse_file(@fixture_path)
    struct = items.find { |i| i.name == "TestStruct" }

    refute_nil struct
    assert_equal :struct, struct.type
    assert_equal "test", struct.category
    assert_equal "A test structure for unit testing.", struct.brief
  end

  def test_parse_file_extracts_struct_members
    items = @parser.parse_file(@fixture_path)
    struct = items.find { |i| i.name == "TestStruct" }

    assert_equal 2, struct.members.size
    assert_equal "The name field.", struct.members.first.description
  end

  def test_parse_file_extracts_enum
    items = @parser.parse_file(@fixture_path)
    enum = items.find { |i| i.name == "TestEnum" }

    refute_nil enum
    assert_equal :enum, enum.type
    assert_equal "test", enum.category
    assert_equal "A test enumeration.", enum.brief
  end

  def test_parse_file_extracts_enum_entries
    items = @parser.parse_file(@fixture_path)
    enum = items.find { |i| i.name == "TestEnum" }

    assert_equal 2, enum.entries.size
    assert_equal "CF_TEST_VALUE_ONE", enum.entries.first.name
    assert_equal "0", enum.entries.first.value
    assert_equal "First test value.", enum.entries.first.description
  end

  def test_parse_file_extracts_function
    items = @parser.parse_file(@fixture_path)
    func = items.find { |i| i.name == "test_function" }

    refute_nil func
    assert_equal :function, func.type
    assert_equal "test", func.category
    assert_equal "A test function for unit testing.", func.brief
  end

  def test_parse_file_extracts_function_params
    items = @parser.parse_file(@fixture_path)
    func = items.find { |i| i.name == "test_function" }

    assert_equal 2, func.parameters.size
    assert_equal "input", func.parameters.first.name
    assert_equal "The input parameter.", func.parameters.first.description
  end

  def test_parse_file_extracts_function_signature
    items = @parser.parse_file(@fixture_path)
    func = items.find { |i| i.name == "test_function" }

    assert_includes func.signature, "test_function"
    refute_includes func.signature, "CF_API"
    refute_includes func.signature, "CF_CALL"
  end

  def test_parse_file_extracts_related
    items = @parser.parse_file(@fixture_path)
    struct = items.find { |i| i.name == "TestStruct" }

    assert_includes struct.related, "test_function"
    assert_includes struct.related, "TestEnum"
  end
end
