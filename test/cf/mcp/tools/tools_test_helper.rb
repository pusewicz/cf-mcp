# frozen_string_literal: true

require "test_helper"

module ToolsTestHelper
  def setup_test_index
    @index = CF::MCP::Index.instance
    @index.reset!
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_make_sprite",
      category: "sprite",
      brief: "Loads a sprite from an aseprite file.",
      signature: "CF_Sprite cf_make_sprite(const char* path)",
      parameters: [
        CF::MCP::Models::FunctionDoc::Parameter.new("path", "Path to the .ase file")
      ],
      return_value: "Returns a CF_Sprite",
      related: ["CF_Sprite", "cf_draw_sprite"]
    ))
    @index.add(CF::MCP::Models::FunctionDoc.new(
      name: "cf_draw_sprite",
      category: "sprite",
      brief: "Draws a sprite on screen."
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

    @server_context = {index: @index}
  end
end
