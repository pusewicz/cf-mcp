# frozen_string_literal: true

require "test_helper"

module ToolsTestHelper
  def setup_test_index
    @index = CF::MCP::Index.new
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_sprite",
      category: "sprite",
      brief: "Loads a sprite from an aseprite file.",
      signature: "CF_Sprite cf_make_sprite(const char* path)",
      parameters: [
        CF::MCP::Models::FunctionDoc::Parameter.new("path", "Path to the .ase file")
      ],
      return_value: "Returns a CF_Sprite",
      related: ["CF_Sprite", "cf_draw_sprite", "nonexistent_item"]
    ))
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_draw_sprite",
      category: "sprite",
      brief: "Draws a sprite on screen.",
      related: ["cf_make_sprite"]
    ))
    @index.add(CF::MCP::Models::StructDoc.new(
      name: "CF_Sprite",
      category: "sprite",
      brief: "A sprite represents a drawable entity.",
      members: [
        CF::MCP::Models::StructDoc::Member.new("const char* name", "The sprite name"),
        CF::MCP::Models::StructDoc::Member.new("int w", "Width in pixels")
      ]
    ))
    @index.add(CF::MCP::Models::EnumDoc.new(
      name: "CF_PlayDirection",
      category: "sprite",
      brief: "The direction a sprite plays frames.",
      entries: [
        CF::MCP::Models::EnumDoc::Entry.new("PLAY_DIRECTION_FORWARDS", "0", "Play forwards"),
        CF::MCP::Models::EnumDoc::Entry.new("PLAY_DIRECTION_BACKWARDS", "1", "Play backwards")
      ]
    ))
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_app",
      category: "app",
      brief: "Creates an application window."
    ))
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_no_related",
      category: "misc",
      brief: "A function with no related items.",
      related: []
    ))

    @server_context = {index: @index}
  end

  def setup_test_index_with_topics
    setup_test_index

    @index.add(CF::MCP::Models::TopicDoc.new(
      name: "sprite_guide",
      category: "sprite",
      brief: "Guide to using sprites",
      content: "# Sprite Guide\n\nContent here.",
      function_references: ["cf_make_sprite", "cf_draw_sprite"],
      struct_references: ["CF_Sprite"],
      reading_order: 0
    ))

    @index.add(CF::MCP::Models::TopicDoc.new(
      name: "app_guide",
      category: "app",
      brief: "Application guide",
      content: "# App Guide\n\nContent here.",
      function_references: ["cf_make_app"],
      reading_order: 1
    ))
  end
end
