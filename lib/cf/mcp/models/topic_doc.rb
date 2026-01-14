# frozen_string_literal: true

module CF
  module MCP
    module Models
      class TopicDoc < DocItem
        attr_accessor :content, :sections, :function_references, :struct_references,
          :enum_references, :topic_references, :reading_order

        Section = Data.define(:title, :content)

        def initialize(
          content: nil,
          sections: [],
          function_references: [],
          struct_references: [],
          enum_references: [],
          topic_references: [],
          reading_order: nil,
          **kwargs
        )
          super(type: :topic, **kwargs)
          @content = content
          @sections = sections || []
          @function_references = function_references || []
          @struct_references = struct_references || []
          @enum_references = enum_references || []
          @topic_references = topic_references || []
          @reading_order = reading_order
        end

        def all_api_references
          function_references + struct_references + enum_references
        end

        def to_h
          super.merge(
            content: content,
            sections: sections.map { |s| {title: s.title, content: s.content} },
            function_references: function_references,
            struct_references: struct_references,
            enum_references: enum_references,
            topic_references: topic_references,
            reading_order: reading_order
          ).compact
        end

        def to_summary
          "- **#{name}** `(topic)` — #{brief}"
        end

        def to_text(detailed: false, index: nil)
          lines = []
          lines << "# #{name}"
          lines << ""
          lines << "**Type:** topic"
          lines << "**Category:** #{category}" if category
          lines << "**Source:** #{source_file}" if source_file
          lines << ""
          lines << "## Overview"
          lines << brief if brief
          lines << ""

          if detailed
            lines << "## Content"
            lines << ""
            lines << content if content
            lines << ""

            if function_references.any?
              lines << "## Referenced Functions"
              lines << format_api_references(function_references, index)
              lines << ""
            end

            if struct_references.any?
              lines << "## Referenced Structs"
              lines << format_api_references(struct_references, index)
              lines << ""
            end

            if enum_references.any?
              lines << "## Referenced Enums"
              lines << format_api_references(enum_references, index)
              lines << ""
            end

            if topic_references.any?
              lines << "## Related Topics"
              lines << topic_references.map { |t| "- #{t}" }.join("\n")
              lines << ""
            end
          end

          lines.join("\n")
        end

        private

        def format_api_references(refs, index)
          refs.map do |ref_name|
            if index
              info = index.brief_for(ref_name)
              info ? "- `#{info[:name]}` — #{info[:brief]}" : "- `#{ref_name}`"
            else
              "- `#{ref_name}`"
            end
          end.join("\n")
        end
      end
    end
  end
end
