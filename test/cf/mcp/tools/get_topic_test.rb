# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::GetTopicTest < Minitest::Test
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
      content: "# Audio\n\nFull audio content here.",
      function_references: ["cf_make_sprite"],
      struct_references: ["CF_Sprite"],
      enum_references: ["CF_PlayDirection"],
      topic_references: ["drawing"]
    ))

    @index.add(CF::MCP::Models::TopicDoc.new(
      name: "drawing",
      category: "draw",
      brief: "Drawing and rendering guide",
      content: "# Drawing\n\nFull drawing content here."
    ))
  end

  def test_gets_topic_content
    response = CF::MCP::Tools::GetTopic.call(name: "audio", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "# audio"
    assert_includes text, "Audio playback"
  end

  def test_topic_not_found_shows_suggestions
    response = CF::MCP::Tools::GetTopic.call(name: "audi", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Topic not found"
    assert_includes text, "Similar topics"
    assert_includes text, "audio"
  end

  def test_topic_not_found_no_suggestions
    empty_index = CF::MCP::Index.new
    response = CF::MCP::Tools::GetTopic.call(name: "nonexistent", server_context: {index: empty_index})

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Topic not found"
    assert_includes text, "cf_list_topics"
    refute_includes text, "Similar topics"
  end

  def test_handles_missing_index
    response = CF::MCP::Tools::GetTopic.call(name: "test", server_context: {})

    assert response.error?
    assert_includes response.content.first[:text], "Index not available"
  end

  def test_returns_detailed_text
    response = CF::MCP::Tools::GetTopic.call(name: "audio", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "## Content"
  end

  def test_finding_non_topic_item_returns_not_found
    # Try to find a function which exists but isn't a topic
    response = CF::MCP::Tools::GetTopic.call(name: "cf_make_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Topic not found"
  end

  def test_fuzzy_match_with_underscores_removed
    # "aud" without underscores should still find "audio"
    @index.add(CF::MCP::Models::TopicDoc.new(
      name: "game_loop",
      category: "app",
      brief: "Game loop guide"
    ))

    response = CF::MCP::Tools::GetTopic.call(name: "gameloop", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Similar topics"
    assert_includes text, "game_loop"
  end
end
