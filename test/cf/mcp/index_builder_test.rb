# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class CF::MCP::IndexBuilderTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("cf-mcp-builder-test")
    @include_dir = File.join(@temp_dir, "include")
    FileUtils.mkdir_p(@include_dir)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.directory?(@temp_dir)
  end

  def test_initialize_with_root_option
    builder = CF::MCP::IndexBuilder.new(root: @include_dir)

    assert_equal @include_dir, builder.headers_path
  end

  def test_initialize_with_env_variable
    original_env = ENV["CF_HEADERS_PATH"]
    ENV["CF_HEADERS_PATH"] = @include_dir

    builder = CF::MCP::IndexBuilder.new

    assert_equal @include_dir, builder.headers_path
  ensure
    ENV["CF_HEADERS_PATH"] = original_env
  end

  def test_valid_returns_true_for_existing_directory
    builder = CF::MCP::IndexBuilder.new(root: @include_dir)

    assert builder.valid?
  end

  def test_valid_returns_false_for_nonexistent_directory
    builder = CF::MCP::IndexBuilder.new(root: "/nonexistent/path")

    refute builder.valid?
  end

  def test_build_returns_index
    File.write(File.join(@include_dir, "test.h"), <<~HEADER)
      /**
       * @function test_func
       * @category test
       * @brief A test function.
       */
      void test_func(void);
    HEADER

    builder = CF::MCP::IndexBuilder.new(root: @include_dir)
    index = builder.build

    assert_kind_of CF::MCP::Index, index
    assert_equal 1, index.stats[:functions]
  end

  def test_build_parses_multiple_header_files
    File.write(File.join(@include_dir, "func.h"), <<~HEADER)
      /**
       * @function func_one
       * @category test
       * @brief First function.
       */
      void func_one(void);
    HEADER

    File.write(File.join(@include_dir, "struct.h"), <<~HEADER)
      /**
       * @struct MyStruct
       * @category test
       * @brief A struct.
       */
      typedef struct MyStruct { int x; } MyStruct;
    HEADER

    builder = CF::MCP::IndexBuilder.new(root: @include_dir)
    index = builder.build

    assert_equal 1, index.stats[:functions]
    assert_equal 1, index.stats[:structs]
  end

  def test_build_parses_topics_when_available
    topics_dir = File.join(@temp_dir, "docs", "topics")
    FileUtils.mkdir_p(topics_dir)

    File.write(File.join(topics_dir, "audio.md"), <<~MARKDOWN)
      # Audio

      Audio documentation.
    MARKDOWN

    builder = CF::MCP::IndexBuilder.new(root: @include_dir)
    index = builder.build

    assert_equal 1, index.stats[:topics]
  end

  def test_build_calls_block_for_topics
    topics_dir = File.join(@temp_dir, "docs", "topics")
    FileUtils.mkdir_p(topics_dir)

    File.write(File.join(topics_dir, "audio.md"), "# Audio\n\nBrief.")

    builder = CF::MCP::IndexBuilder.new(root: @include_dir)
    block_called = false
    event_received = nil
    count_received = nil

    builder.build do |event, _path, count|
      block_called = true
      event_received = event
      count_received = count
    end

    assert block_called
    assert_equal :topics_indexed, event_received
    assert_equal 1, count_received
  end

  def test_build_finds_topics_in_alternative_location
    topics_dir = File.join(@temp_dir, "topics")
    FileUtils.mkdir_p(topics_dir)

    File.write(File.join(topics_dir, "input.md"), "# Input\n\nInput docs.")

    builder = CF::MCP::IndexBuilder.new(root: @include_dir)
    index = builder.build

    assert_equal 1, index.stats[:topics]
  end

  def test_build_refines_topic_enum_references
    File.write(File.join(@include_dir, "test.h"), <<~HEADER)
      /**
       * @enum MY_ENUM
       * @category test
       * @brief An enum.
       */
      #define MY_ENUM_DEFS \\
      /* @entry First */ CF_ENUM(MY_ENUM_ONE, 0) \\
    HEADER

    topics_dir = File.join(@temp_dir, "docs", "topics")
    FileUtils.mkdir_p(topics_dir)

    File.write(File.join(topics_dir, "test.md"), <<~MARKDOWN)
      # Test

      See [MY_ENUM](../test/MY_ENUM.md) for details.
    MARKDOWN

    builder = CF::MCP::IndexBuilder.new(root: @include_dir)
    index = builder.build

    topic = index.find("test")
    # MY_ENUM should be moved from struct_references to enum_references
    assert_includes topic.enum_references, "MY_ENUM"
    refute_includes topic.struct_references, "MY_ENUM"
  end

  def test_root_takes_precedence_over_env
    original_env = ENV["CF_HEADERS_PATH"]
    ENV["CF_HEADERS_PATH"] = "/env/path"

    builder = CF::MCP::IndexBuilder.new(root: @include_dir)

    assert_equal @include_dir, builder.headers_path
  ensure
    ENV["CF_HEADERS_PATH"] = original_env
  end

  def test_uses_default_path_when_no_root_or_env
    original_env = ENV["CF_HEADERS_PATH"]
    ENV.delete("CF_HEADERS_PATH")

    builder = CF::MCP::IndexBuilder.new(root: nil, download: false)

    assert_equal CF::MCP::IndexBuilder::DEFAULT_HEADERS_PATH, builder.headers_path
  ensure
    ENV["CF_HEADERS_PATH"] = original_env
  end
end
