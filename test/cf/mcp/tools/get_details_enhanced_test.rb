# frozen_string_literal: true

require_relative "tools_test_helper"

class CF::MCP::Tools::GetDetailsEnhancedTest < Minitest::Test
  include ToolsTestHelper

  def setup
    setup_test_index_with_topics
  end

  def test_shows_related_topics_for_function
    response = CF::MCP::Tools::GetDetails.call(name: "cf_make_sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "## Related Topics"
    assert_includes text, "sprite_guide"
    assert_includes text, "cf_get_topic"
  end

  def test_shows_related_topics_for_struct
    response = CF::MCP::Tools::GetDetails.call(name: "CF_Sprite", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    assert_includes text, "## Related Topics"
    assert_includes text, "sprite_guide"
  end

  def test_no_related_topics_section_for_topic
    response = CF::MCP::Tools::GetDetails.call(name: "sprite_guide", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    # Topics themselves shouldn't show a "Related Topics" section
    assert_includes text, "# sprite_guide"
  end

  def test_item_with_no_related_topics
    response = CF::MCP::Tools::GetDetails.call(name: "cf_no_related", server_context: @server_context)

    refute response.error?
    text = response.content.first[:text]
    refute_includes text, "## Related Topics"
  end

  def test_topic_reverse_index
    # Verify the topic reverse index is built correctly
    topics = @index.topics_for("cf_make_sprite")

    assert_equal 1, topics.size
    assert_equal "sprite_guide", topics.first.name
  end
end
