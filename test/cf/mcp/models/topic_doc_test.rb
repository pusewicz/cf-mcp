# frozen_string_literal: true

require "test_helper"

class CF::MCP::Models::TopicDocTest < Minitest::Test
  def setup
    @topic = CF::MCP::Models::TopicDoc.new(
      name: "audio",
      brief: "Audio playback and music",
      category: "audio",
      content: "# Audio\n\nFull audio content here.",
      sections: [
        CF::MCP::Models::TopicDoc::Section.new(title: "Music", content: "Music details"),
        CF::MCP::Models::TopicDoc::Section.new(title: "Sound FX", content: "Sound details")
      ],
      function_references: ["cf_audio_load_wav", "cf_play_sound"],
      struct_references: ["CF_Audio"],
      enum_references: ["CF_SoundFormat"],
      topic_references: ["collision"],
      reading_order: 3,
      source_file: "audio.md"
    )
  end

  def test_type_is_topic
    assert_equal :topic, @topic.type
  end

  def test_all_api_references
    refs = @topic.all_api_references

    assert_includes refs, "cf_audio_load_wav"
    assert_includes refs, "cf_play_sound"
    assert_includes refs, "CF_Audio"
    assert_includes refs, "CF_SoundFormat"
    assert_equal 4, refs.size
  end

  def test_to_h
    hash = @topic.to_h

    assert_equal "audio", hash[:name]
    assert_equal :topic, hash[:type]
    assert_equal "audio", hash[:category]
    assert_includes hash[:content], "Audio"
    assert_equal 2, hash[:sections].size
    assert_equal ["cf_audio_load_wav", "cf_play_sound"], hash[:function_references]
    assert_equal ["CF_Audio"], hash[:struct_references]
    assert_equal ["CF_SoundFormat"], hash[:enum_references]
    assert_equal ["collision"], hash[:topic_references]
    assert_equal 3, hash[:reading_order]
  end

  def test_to_summary
    summary = @topic.to_summary

    assert_includes summary, "**audio**"
    assert_includes summary, "(topic)"
    assert_includes summary, "Audio playback and music"
  end

  def test_to_text_basic
    text = @topic.to_text

    assert_includes text, "# audio"
    assert_includes text, "**Type:** topic"
    assert_includes text, "**Category:** audio"
    assert_includes text, "Audio playback and music"
  end

  def test_to_text_detailed_includes_content
    text = @topic.to_text(detailed: true)

    assert_includes text, "## Content"
    assert_includes text, "Full audio content here."
  end

  def test_to_text_detailed_includes_function_references
    text = @topic.to_text(detailed: true)

    assert_includes text, "## Referenced Functions"
    assert_includes text, "cf_audio_load_wav"
    assert_includes text, "cf_play_sound"
  end

  def test_to_text_detailed_includes_struct_references
    text = @topic.to_text(detailed: true)

    assert_includes text, "## Referenced Structs"
    assert_includes text, "CF_Audio"
  end

  def test_to_text_detailed_includes_enum_references
    text = @topic.to_text(detailed: true)

    assert_includes text, "## Referenced Enums"
    assert_includes text, "CF_SoundFormat"
  end

  def test_to_text_detailed_includes_topic_references
    text = @topic.to_text(detailed: true)

    assert_includes text, "## Related Topics"
    assert_includes text, "collision"
  end

  def test_to_text_with_index_enriches_references
    index = CF::MCP::Index.instance
    index.reset!
    index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_audio_load_wav",
      category: "audio",
      brief: "Loads a .wav file"
    ))

    text = @topic.to_text(detailed: true, index: index)

    assert_includes text, "cf_audio_load_wav"
    assert_includes text, "Loads a .wav file"
  end

  def test_defaults_to_empty_arrays
    topic = CF::MCP::Models::TopicDoc.new(name: "empty")

    assert_equal [], topic.function_references
    assert_equal [], topic.struct_references
    assert_equal [], topic.enum_references
    assert_equal [], topic.topic_references
    assert_equal [], topic.sections
    assert_nil topic.reading_order
  end
end
