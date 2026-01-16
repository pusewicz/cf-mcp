# frozen_string_literal: true

require "test_helper"

class CF::MCP::Models::TopicDocTest < Minitest::Test
  def test_initialize_with_defaults
    topic = CF::MCP::Models::TopicDoc.new(
      name: "test",
      brief: "Test topic"
    )

    assert_equal "test", topic.name
    assert_equal :topic, topic.type
    assert_equal "Test topic", topic.brief
    assert_equal [], topic.function_references
    assert_equal [], topic.struct_references
    assert_equal [], topic.enum_references
    assert_equal [], topic.topic_references
    assert_equal [], topic.sections
    assert_nil topic.reading_order
  end

  def test_initialize_with_all_options
    topic = CF::MCP::Models::TopicDoc.new(
      name: "audio",
      brief: "Audio guide",
      category: "audio",
      content: "# Audio content",
      sections: [CF::MCP::Models::TopicDoc::Section.new(title: "Intro", content: "Intro content")],
      function_references: ["cf_play_sound"],
      struct_references: ["CF_Sound"],
      enum_references: ["CF_AudioFormat"],
      topic_references: ["drawing"],
      reading_order: 5
    )

    assert_equal "audio", topic.name
    assert_equal "# Audio content", topic.content
    assert_equal 1, topic.sections.size
    assert_equal ["cf_play_sound"], topic.function_references
    assert_equal ["CF_Sound"], topic.struct_references
    assert_equal ["CF_AudioFormat"], topic.enum_references
    assert_equal ["drawing"], topic.topic_references
    assert_equal 5, topic.reading_order
  end

  def test_all_api_references_combines_all_references
    topic = CF::MCP::Models::TopicDoc.new(
      name: "test",
      function_references: ["func1", "func2"],
      struct_references: ["Struct1"],
      enum_references: ["Enum1", "Enum2"]
    )

    refs = topic.all_api_references

    assert_includes refs, "func1"
    assert_includes refs, "func2"
    assert_includes refs, "Struct1"
    assert_includes refs, "Enum1"
    assert_includes refs, "Enum2"
    assert_equal 5, refs.size
  end

  def test_to_h_includes_all_fields
    topic = CF::MCP::Models::TopicDoc.new(
      name: "test",
      brief: "Test brief",
      category: "test",
      content: "Content here",
      sections: [CF::MCP::Models::TopicDoc::Section.new(title: "Sec", content: "Con")],
      function_references: ["func"],
      struct_references: ["struct"],
      enum_references: ["enum"],
      topic_references: ["other"],
      reading_order: 1
    )

    hash = topic.to_h

    assert_equal "test", hash[:name]
    assert_equal :topic, hash[:type]
    assert_equal "Content here", hash[:content]
    assert_equal 1, hash[:sections].size
    assert_equal ["func"], hash[:function_references]
    assert_equal 1, hash[:reading_order]
  end

  def test_to_summary
    topic = CF::MCP::Models::TopicDoc.new(
      name: "audio",
      brief: "Audio playback guide"
    )

    summary = topic.to_summary

    assert_includes summary, "**audio**"
    assert_includes summary, "(topic)"
    assert_includes summary, "Audio playback guide"
  end

  def test_to_text_basic
    topic = CF::MCP::Models::TopicDoc.new(
      name: "audio",
      brief: "Audio guide",
      category: "audio",
      source_file: "audio.md"
    )

    text = topic.to_text(detailed: false)

    assert_includes text, "# audio"
    assert_includes text, "**Type:** topic"
    assert_includes text, "**Category:** audio"
    assert_includes text, "**Source:** audio.md"
    assert_includes text, "Audio guide"
  end

  def test_to_text_detailed_with_content
    topic = CF::MCP::Models::TopicDoc.new(
      name: "audio",
      brief: "Audio guide",
      content: "Full content markdown here"
    )

    text = topic.to_text(detailed: true)

    assert_includes text, "## Content"
    assert_includes text, "Full content markdown here"
  end

  def test_to_text_detailed_with_function_references
    index = CF::MCP::Index.new
    index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_play_sound",
      brief: "Plays a sound"
    ))

    topic = CF::MCP::Models::TopicDoc.new(
      name: "audio",
      brief: "Audio guide",
      function_references: ["cf_play_sound"]
    )

    text = topic.to_text(detailed: true, index: index)

    assert_includes text, "## Referenced Functions"
    assert_includes text, "cf_play_sound"
    assert_includes text, "Plays a sound"
  end

  def test_to_text_detailed_with_struct_references
    index = CF::MCP::Index.new
    index.add(CF::MCP::Models::StructDoc.new(
      name: "CF_Sound",
      brief: "Sound handle"
    ))

    topic = CF::MCP::Models::TopicDoc.new(
      name: "audio",
      brief: "Audio guide",
      struct_references: ["CF_Sound"]
    )

    text = topic.to_text(detailed: true, index: index)

    assert_includes text, "## Referenced Structs"
    assert_includes text, "CF_Sound"
    assert_includes text, "Sound handle"
  end

  def test_to_text_detailed_with_enum_references
    index = CF::MCP::Index.new
    index.add(CF::MCP::Models::EnumDoc.new(
      name: "CF_AudioFormat",
      brief: "Audio formats"
    ))

    topic = CF::MCP::Models::TopicDoc.new(
      name: "audio",
      brief: "Audio guide",
      enum_references: ["CF_AudioFormat"]
    )

    text = topic.to_text(detailed: true, index: index)

    assert_includes text, "## Referenced Enums"
    assert_includes text, "CF_AudioFormat"
    assert_includes text, "Audio formats"
  end

  def test_to_text_detailed_with_topic_references
    topic = CF::MCP::Models::TopicDoc.new(
      name: "audio",
      brief: "Audio guide",
      topic_references: ["drawing", "input"]
    )

    text = topic.to_text(detailed: true)

    assert_includes text, "## Related Topics"
    assert_includes text, "- drawing"
    assert_includes text, "- input"
  end

  def test_format_api_references_without_index
    topic = CF::MCP::Models::TopicDoc.new(
      name: "test",
      function_references: ["func1", "func2"]
    )

    # Access private method for testing
    formatted = topic.send(:format_api_references, topic.function_references, nil)

    assert_includes formatted, "- `func1`"
    assert_includes formatted, "- `func2`"
  end

  def test_format_api_references_with_index_not_found
    index = CF::MCP::Index.new

    topic = CF::MCP::Models::TopicDoc.new(
      name: "test",
      function_references: ["nonexistent"]
    )

    formatted = topic.send(:format_api_references, topic.function_references, index)

    assert_includes formatted, "- `nonexistent`"
    refute_includes formatted, "—"
  end
end
