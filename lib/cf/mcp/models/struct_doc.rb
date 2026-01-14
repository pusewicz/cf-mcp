# frozen_string_literal: true

require_relative "doc_item"

module CF
  module MCP
    module Models
      class StructDoc < DocItem
        attr_accessor :members

        Member = Data.define(:declaration, :description)

        def initialize(
          members: [],
          **kwargs
        )
          super(type: :struct, **kwargs)
          @members = members || []
        end

        def to_h
          super.merge(
            members: members.map { |m| {declaration: m.declaration, description: m.description} }
          ).compact
        end

        def to_text(detailed: false, index: nil)
          lines = []
          lines << "# #{name}"
          lines << ""
          lines << "**Type:** struct"
          lines << "**Category:** #{category}" if category
          lines << "**Source:** #{source_file}" if source_file
          lines << ""
          lines << "## Description"
          lines << brief if brief
          lines << ""

          if detailed
            if members && !members.empty?
              lines << "## Members"
              lines << ""
              lines << "| Member | Description |"
              lines << "| --- | --- |"
              members.each do |member|
                lines << "| `#{member.declaration}` | #{member.description} |"
              end
              lines << ""
            end

            if remarks && !remarks.empty?
              lines << "## Remarks"
              lines << remarks
              lines << ""
            end

            if example && !example.empty?
              lines << "## Example"
              lines << example_brief if example_brief
              lines << "```c"
              lines << example
              lines << "```"
              lines << ""
            end

            if related && !related.empty?
              lines << "## Related"
              lines << format_related_items(index)
              lines << ""
            end
          end

          lines.join("\n")
        end
      end
    end
  end
end
