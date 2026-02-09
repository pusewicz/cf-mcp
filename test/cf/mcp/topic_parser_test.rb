# frozen_string_literal: true

require "test_helper"

class CF::MCP::TopicParserTest < Minitest::Test
  def setup
    @parser = CF::MCP::TopicParser.new
    @fixtures_path = File.expand_path("../../fixtures/topics", __dir__)
  end

  def test_parse_file_returns_topic_doc
    topic = @parser.parse_file(File.join(@fixtures_path, "sample_topic.md"))

    assert_instance_of CF::MCP::Models::TopicDoc, topic
    assert_equal "sample_topic", topic.name
    assert_equal :topic, topic.type
  end

  def test_parse_file_extracts_brief
    topic = @parser.parse_file(File.join(@fixtures_path, "sample_topic.md"))

    assert_includes topic.brief, "sample topic for testing"
  end

  def test_parse_file_extracts_sections
    topic = @parser.parse_file(File.join(@fixtures_path, "sample_topic.md"))

    section_titles = topic.sections.map(&:title)
    assert_includes section_titles, "Music"
    assert_includes section_titles, "Sound FX"
  end

  def test_parse_file_extracts_function_references
    topic = @parser.parse_file(File.join(@fixtures_path, "sample_topic.md"))

    assert_includes topic.function_references, "cf_audio_load_wav"
    assert_includes topic.function_references, "cf_audio_load_ogg"
    assert_includes topic.function_references, "cf_play_sound"
  end

  def test_parse_file_extracts_struct_references
    topic = @parser.parse_file(File.join(@fixtures_path, "sample_topic.md"))

    assert_includes topic.struct_references, "CF_Audio"
    assert_includes topic.struct_references, "CF_Sound"
  end

  def test_parse_file_extracts_topic_references
    topic = @parser.parse_file(File.join(@fixtures_path, "sample_topic.md"))

    assert_includes topic.topic_references, "collision"
  end

  def test_parse_file_skips_index
    result = @parser.parse_file(File.join(@fixtures_path, "index.md"))

    assert_nil result
  end

  def test_parse_file_derives_category
    topic = @parser.parse_file(File.join(@fixtures_path, "sample_topic.md"))

    # "sample_topic" is not in the category map, so it uses the slug as-is
    assert_equal "sample_topic", topic.category
  end

  def test_parse_file_preserves_content
    topic = @parser.parse_file(File.join(@fixtures_path, "sample_topic.md"))

    assert_includes topic.content, "# Sample Topic"
    assert_includes topic.content, "cf_music_play"
  end

  def test_parse_directory_returns_all_topics
    topics = @parser.parse_directory(@fixtures_path)

    assert_equal 2, topics.size
    names = topics.map(&:name)
    assert_includes names, "sample_topic"
    assert_includes names, "another_topic"
  end

  def test_parse_directory_assigns_reading_order
    topics = @parser.parse_directory(@fixtures_path)

    another = topics.find { |t| t.name == "another_topic" }
    sample = topics.find { |t| t.name == "sample_topic" }

    assert_equal 0, another.reading_order
    assert_equal 1, sample.reading_order
  end

  def test_parse_reading_order
    order = @parser.parse_reading_order(File.join(@fixtures_path, "index.md"))

    assert_equal 0, order["another_topic"]
    assert_equal 1, order["sample_topic"]
  end

  def test_parse_reading_order_missing_file
    order = @parser.parse_reading_order("/nonexistent/index.md")

    assert_equal({}, order)
  end

  def test_function_references_are_unique
    topic = @parser.parse_file(File.join(@fixtures_path, "sample_topic.md"))

    assert_equal topic.function_references, topic.function_references.uniq
  end
end
