# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::ListTopicsTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index
    add_test_topics
  end

  def test_lists_all_topics
    response = CF::MCP::Tools::ListTopics.call(server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "audio_guide"
    assert_includes text, "collision_guide"
  end

  def test_filters_by_category
    response = CF::MCP::Tools::ListTopics.call(category: "audio", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "audio_guide"
    refute_includes text, "collision_guide"
  end

  def test_no_topics_found
    response = CF::MCP::Tools::ListTopics.call(category: "nonexistent", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "No topics found"
  end

  def test_ordered_listing
    response = CF::MCP::Tools::ListTopics.call(ordered: true, server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "recommended reading order"
  end

  def test_includes_tip
    response = CF::MCP::Tools::ListTopics.call(server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "get_topic"
  end

  private

  def add_test_topics
    @index.add(CF::MCP::Models::TopicDoc.new(
      name: "audio_guide",
      brief: "Guide to audio features",
      category: "audio",
      content: "# Audio Guide\n\nContent here.",
      reading_order: 0
    ))
    @index.add(CF::MCP::Models::TopicDoc.new(
      name: "collision_guide",
      brief: "Guide to collision detection",
      category: "collision",
      content: "# Collision Guide\n\nContent here.",
      reading_order: 1
    ))
  end
end
