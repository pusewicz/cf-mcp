# frozen_string_literal: true

require "test_helper"

class CF::MCP::IndexBuilderTest < Minitest::Test
  def setup
    @fixtures_path = File.expand_path("../../fixtures", __dir__)
    @headers_path = @fixtures_path
  end

  def test_build_indexes_headers
    builder = CF::MCP::IndexBuilder.new(root: @headers_path)
    index = builder.build

    assert index.size > 0
    refute_nil index.find("test_function")
    refute_nil index.find("TestStruct")
    refute_nil index.find("TestEnum")
  end

  def test_build_resets_index
    index = CF::MCP::Index.instance
    index.reset!
    index.add(CF::MCP::Models::FunctionDoc.new(name: "leftover_func", category: "old"))

    builder = CF::MCP::IndexBuilder.new(root: @headers_path)
    builder.build

    assert_nil CF::MCP::Index.instance.find("leftover_func")
  end

  def test_valid_with_existing_directory
    builder = CF::MCP::IndexBuilder.new(root: @headers_path)

    assert builder.valid?
  end

  def test_valid_with_nonexistent_directory
    builder = CF::MCP::IndexBuilder.new(root: "/nonexistent/path")

    refute builder.valid?
  end

  def test_headers_path_uses_root_when_provided
    builder = CF::MCP::IndexBuilder.new(root: "/custom/path")

    assert_equal "/custom/path", builder.headers_path
  end

  def test_headers_path_uses_env_variable
    original = ENV["CF_HEADERS_PATH"]
    ENV["CF_HEADERS_PATH"] = "/env/path"

    builder = CF::MCP::IndexBuilder.new
    assert_equal "/env/path", builder.headers_path
  ensure
    if original
      ENV["CF_HEADERS_PATH"] = original
    else
      ENV.delete("CF_HEADERS_PATH")
    end
  end

  def test_build_yields_topics_indexed_event
    # Create a temporary structure with headers and topics
    Dir.mktmpdir do |dir|
      headers_dir = File.join(dir, "include")
      topics_dir = File.join(dir, "docs", "topics")
      FileUtils.mkdir_p(headers_dir)
      FileUtils.mkdir_p(topics_dir)

      # Copy sample header
      FileUtils.cp(File.join(@fixtures_path, "sample_header.h"), headers_dir)

      # Create a simple topic
      File.write(File.join(topics_dir, "test_topic.md"), "# Test\n\nA test topic.")

      builder = CF::MCP::IndexBuilder.new(root: headers_dir)
      events = []
      builder.build { |event, path, count| events << [event, count] }

      assert events.any? { |e| e[0] == :topics_indexed }
    end
  end

  def test_build_indexes_topics_when_available
    Dir.mktmpdir do |dir|
      headers_dir = File.join(dir, "include")
      topics_dir = File.join(dir, "docs", "topics")
      FileUtils.mkdir_p(headers_dir)
      FileUtils.mkdir_p(topics_dir)

      FileUtils.cp(File.join(@fixtures_path, "sample_header.h"), headers_dir)
      File.write(File.join(topics_dir, "my_topic.md"), "# My Topic\n\nA topic about things.")

      builder = CF::MCP::IndexBuilder.new(root: headers_dir)
      index = builder.build

      topic = index.find("my_topic")
      refute_nil topic
      assert_equal :topic, topic.type
    end
  end
end
