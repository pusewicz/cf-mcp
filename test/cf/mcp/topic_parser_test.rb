# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class CF::MCP::TopicParserTest < Minitest::Test
  def setup
    @parser = CF::MCP::TopicParser.new
    @temp_dir = Dir.mktmpdir("cf-mcp-topic-test")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.directory?(@temp_dir)
  end

  def test_parse_file_returns_topic_doc
    topic_path = File.join(@temp_dir, "test_topic.md")
    File.write(topic_path, <<~MARKDOWN)
      # Test Topic

      This is a test topic about sprites.

      ## Section One

      Content here.

      ## Section Two

      More content.
    MARKDOWN

    topic = @parser.parse_file(topic_path)

    assert_kind_of CF::MCP::Models::TopicDoc, topic
    assert_equal "test_topic", topic.name
    assert_equal :topic, topic.type
  end

  def test_parse_file_returns_nil_for_index
    index_path = File.join(@temp_dir, "index.md")
    File.write(index_path, "# Index")

    assert_nil @parser.parse_file(index_path)
  end

  def test_parse_file_extracts_brief
    topic_path = File.join(@temp_dir, "audio.md")
    File.write(topic_path, <<~MARKDOWN)
      # Audio

      This is the brief description of audio.

      More details here.
    MARKDOWN

    topic = @parser.parse_file(topic_path)

    assert_equal "This is the brief description of audio.", topic.brief
  end

  def test_parse_file_extracts_sections
    topic_path = File.join(@temp_dir, "drawing.md")
    File.write(topic_path, <<~MARKDOWN)
      # Drawing

      Brief intro.

      ## Getting Started

      Start here.

      ## Advanced

      More advanced stuff.
    MARKDOWN

    topic = @parser.parse_file(topic_path)

    assert_equal 2, topic.sections.size
    assert_equal "Getting Started", topic.sections[0].title
    assert_equal "Advanced", topic.sections[1].title
  end

  def test_parse_file_extracts_function_references
    topic_path = File.join(@temp_dir, "input.md")
    File.write(topic_path, <<~MARKDOWN)
      # Input

      Use [`cf_input_text`](../input/cf_input_text.md) for text input.
      Also see [cf_key_down](../input/cf_key_down.md).
    MARKDOWN

    topic = @parser.parse_file(topic_path)

    assert_includes topic.function_references, "cf_input_text"
    assert_includes topic.function_references, "cf_key_down"
  end

  def test_parse_file_extracts_struct_references
    topic_path = File.join(@temp_dir, "sprites.md")
    File.write(topic_path, <<~MARKDOWN)
      # Sprites

      Create a [CF_Sprite](../sprite/CF_Sprite.md) object.
    MARKDOWN

    topic = @parser.parse_file(topic_path)

    assert_includes topic.struct_references, "CF_Sprite"
  end

  def test_parse_file_extracts_topic_references
    topic_path = File.join(@temp_dir, "sprites.md")
    File.write(topic_path, <<~MARKDOWN)
      # Sprites

      See also [Drawing](./drawing.md).
      And check out [Animation](../topics/animation.md).
    MARKDOWN

    topic = @parser.parse_file(topic_path)

    assert_includes topic.topic_references, "drawing"
    assert_includes topic.topic_references, "animation"
  end

  def test_parse_directory_returns_array_of_topics
    File.write(File.join(@temp_dir, "audio.md"), "# Audio\n\nAudio brief.")
    File.write(File.join(@temp_dir, "drawing.md"), "# Drawing\n\nDrawing brief.")
    File.write(File.join(@temp_dir, "index.md"), "# Index")

    topics = @parser.parse_directory(@temp_dir)

    assert_equal 2, topics.size
    names = topics.map(&:name)
    assert_includes names, "audio"
    assert_includes names, "drawing"
  end

  def test_parse_directory_sets_reading_order
    File.write(File.join(@temp_dir, "index.md"), <<~MARKDOWN)
      # Topics

      1. [Audio](./audio.md)
      2. [Drawing](./drawing.md)
    MARKDOWN
    File.write(File.join(@temp_dir, "audio.md"), "# Audio\n\nAudio brief.")
    File.write(File.join(@temp_dir, "drawing.md"), "# Drawing\n\nDrawing brief.")

    topics = @parser.parse_directory(@temp_dir)

    audio = topics.find { |t| t.name == "audio" }
    drawing = topics.find { |t| t.name == "drawing" }

    assert_equal 0, audio.reading_order
    assert_equal 1, drawing.reading_order
  end

  def test_parse_reading_order_returns_empty_hash_for_missing_index
    order = @parser.parse_reading_order(File.join(@temp_dir, "nonexistent.md"))

    assert_equal({}, order)
  end

  def test_derive_category_maps_known_slugs
    File.write(File.join(@temp_dir, "audio.md"), "# Audio\n\nBrief.")
    topic = @parser.parse_file(File.join(@temp_dir, "audio.md"))
    assert_equal "audio", topic.category

    File.write(File.join(@temp_dir, "drawing.md"), "# Drawing\n\nBrief.")
    topic = @parser.parse_file(File.join(@temp_dir, "drawing.md"))
    assert_equal "draw", topic.category

    File.write(File.join(@temp_dir, "strings.md"), "# Strings\n\nBrief.")
    topic = @parser.parse_file(File.join(@temp_dir, "strings.md"))
    assert_equal "string", topic.category
  end

  def test_extract_brief_strips_markdown_links
    topic_path = File.join(@temp_dir, "test.md")
    File.write(topic_path, <<~MARKDOWN)
      # Test

      This has a [link](./other.md) in the brief.
    MARKDOWN

    topic = @parser.parse_file(topic_path)

    assert_equal "This has a link in the brief.", topic.brief
  end

  def test_uppercase_names_treated_as_struct_references
    topic_path = File.join(@temp_dir, "test.md")
    File.write(topic_path, <<~MARKDOWN)
      # Test

      See [MyStruct](../test/MyStruct.md) for details.
    MARKDOWN

    topic = @parser.parse_file(topic_path)

    assert_includes topic.struct_references, "MyStruct"
  end
end
