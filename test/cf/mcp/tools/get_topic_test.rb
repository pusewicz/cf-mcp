# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::GetTopicTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index
    add_test_topic
  end

  def test_finds_topic_by_name
    response = CF::MCP::Tools::GetTopic.call(name: "audio_guide", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "audio_guide"
    assert_includes text, "Audio Guide"
  end

  def test_topic_not_found
    response = CF::MCP::Tools::GetTopic.call(name: "nonexistent", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Topic not found"
    assert_includes text, "list_topics"
  end

  def test_suggests_similar_topics
    response = CF::MCP::Tools::GetTopic.call(name: "audio", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Similar topics"
    assert_includes text, "audio_guide"
  end

  def test_non_topic_item_shows_not_found
    # cf_make_sprite exists but is a function, not a topic
    response = CF::MCP::Tools::GetTopic.call(name: "cf_make_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Topic not found"
  end

  def test_detailed_output_includes_content
    response = CF::MCP::Tools::GetTopic.call(name: "audio_guide", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "Content"
  end

  private

  def add_test_topic
    @index.add(CF::MCP::Models::TopicDoc.new(
      name: "audio_guide",
      brief: "Guide to audio features",
      category: "audio",
      content: "# Audio Guide\n\nFull audio content here.",
      sections: [
        CF::MCP::Models::TopicDoc::Section.new(title: "Music", content: "Music content")
      ],
      source_file: "audio_guide.md"
    ))
  end
end
