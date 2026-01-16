# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::ListTopicsTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index_with_topics
  end

  def setup_test_index_with_topics
    setup_test_index

    @index.add(CF::MCP::Models::TopicDoc.new(
      name: "audio",
      category: "audio",
      brief: "Audio playback and music guide",
      content: "# Audio\n\nContent here.",
      reading_order: 0
    ))

    @index.add(CF::MCP::Models::TopicDoc.new(
      name: "drawing",
      category: "draw",
      brief: "Drawing and rendering guide",
      content: "# Drawing\n\nContent here.",
      reading_order: 1
    ))

    @index.add(CF::MCP::Models::TopicDoc.new(
      name: "collision",
      category: "collision",
      brief: "Collision detection guide",
      content: "# Collision\n\nContent here.",
      reading_order: 2
    ))
  end

  def test_lists_all_topics
    response = CF::MCP::Tools::ListTopics.call(server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "audio"
    assert_includes text, "drawing"
    assert_includes text, "collision"
  end

  def test_filters_by_category
    response = CF::MCP::Tools::ListTopics.call(category: "draw", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "drawing"
    refute_includes text, "audio"
    refute_includes text, "collision"
  end

  def test_ordered_list
    response = CF::MCP::Tools::ListTopics.call(ordered: true, server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "recommended reading order"
    assert_includes text, "1. **audio**"
    assert_includes text, "2. **drawing**"
    assert_includes text, "3. **collision**"
  end

  def test_no_topics_found_for_category
    response = CF::MCP::Tools::ListTopics.call(category: "nonexistent", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "No topics found"
    assert_includes text, "nonexistent"
  end

  def test_empty_index
    empty_index = CF::MCP::Index.new
    response = CF::MCP::Tools::ListTopics.call(server_context: {index: empty_index})

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "No topics found"
  end

  def test_handles_missing_index
    response = CF::MCP::Tools::ListTopics.call(server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_includes_get_topic_tip
    response = CF::MCP::Tools::ListTopics.call(server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "cf_get_topic"
  end
end
