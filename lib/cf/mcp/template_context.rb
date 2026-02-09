# frozen_string_literal: true

module CF
  module MCP
    # Helper class to provide a clean binding for ERB templates
    class TemplateContext
      TEMPLATES_DIR = File.join(__dir__, "templates")

      attr_reader :version, :protocol_version, :stats, :categories, :topics, :tools, :tool_schemas_json

      def initialize(version:, protocol_version:, stats:, categories:, topics:, tools:, tool_schemas_json:)
        @version = version
        @protocol_version = protocol_version
        @stats = stats
        @categories = categories
        @topics = topics
        @tools = tools
        @tool_schemas_json = tool_schemas_json
      end

      def categories_json
        @categories.to_json
      end

      def topics_json
        @topics.to_json
      end

      def css_content
        File.read(File.join(TEMPLATES_DIR, "style.css"))
      end

      def changelog_content
        changelog_path = CF::MCP.root.join("CHANGELOG.md")
        changelog_path.exist? ? changelog_path.read : ""
      end

      def changelog_json
        changelog_content.to_json
      end

      def js_content
        js = File.read(File.join(TEMPLATES_DIR, "script.js"))
        js.sub("TOOL_SCHEMAS_PLACEHOLDER", @tool_schemas_json)
          .sub("CATEGORIES_PLACEHOLDER", categories_json)
          .sub("TOPICS_PLACEHOLDER", topics_json)
          .sub("CHANGELOG_PLACEHOLDER", changelog_json)
      end

      def h(text)
        text.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub('"', "&quot;")
          .gsub("'", "&#39;")
      end

      def get_binding
        binding
      end
    end
  end
end
