# frozen_string_literal: true

require_relative "doc_item"

module CF
  module MCP
    module Models
      class EnumDoc < DocItem
        attr_accessor :entries

        Entry = Data.define(:name, :value, :description)

        def initialize(
          entries: [],
          **kwargs
        )
          super(type: :enum, **kwargs)
          @entries = entries || []
        end

        def to_h
          super.merge(
            entries: entries.map { |e| {name: e.name, value: e.value, description: e.description} }
          ).compact
        end

        def to_text(detailed: false, index: nil)
          lines = []
          lines << "# #{name}"
          lines << ""
          lines << "**Type:** enum"
          lines << "**Category:** #{category}" if category
          lines << "**Source:** #{source_file}" if source_file
          lines << ""
          lines << "## Description"
          lines << brief if brief
          lines << ""

          if detailed
            if entries && !entries.empty?
              lines << "## Values"
              lines << ""
              lines << "| Name | Value | Description |"
              lines << "| --- | --- | --- |"
              entries.each do |entry|
                lines << "| `#{entry.name}` | #{entry.value} | #{entry.description} |"
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
