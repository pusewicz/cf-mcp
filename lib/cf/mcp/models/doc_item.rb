# frozen_string_literal: true

module CF
  module MCP
    module Models
      class DocItem
        attr_accessor :name, :type, :category, :brief, :remarks, :example,
          :example_brief, :related, :source_file

        def initialize(
          name: nil,
          type: nil,
          category: nil,
          brief: nil,
          remarks: nil,
          example: nil,
          example_brief: nil,
          related: [],
          source_file: nil
        )
          @name = name
          @type = type
          @category = category
          @brief = brief
          @remarks = remarks
          @example = example
          @example_brief = example_brief
          @related = related || []
          @source_file = source_file
        end

        def matches?(query)
          return true if query.nil? || query.empty?

          pattern = Regexp.new(Regexp.escape(query), Regexp::IGNORECASE)
          [name, brief, remarks, category].any? { |field| field&.match?(pattern) }
        end

        def to_h
          {
            name: name,
            type: type,
            category: category,
            brief: brief,
            remarks: remarks,
            example: example,
            example_brief: example_brief,
            related: related,
            source_file: source_file
          }.compact
        end

        def to_summary
          "- **#{name}** `(#{type}, #{category})` — #{brief}"
        end

        def to_text(detailed: false, index: nil)
          lines = []
          lines << "# #{name}"
          lines << ""
          lines << "**Type:** #{type}"
          lines << "**Category:** #{category}" if category
          lines << "**Source:** #{source_file}" if source_file
          lines << ""
          lines << "## Description"
          lines << brief if brief
          lines << ""

          if detailed
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

        def format_related_items(index)
          return related.join(", ") unless index

          related.map do |rel_name|
            info = index.brief_for(rel_name)
            if info
              "- `#{info[:name]}` (#{info[:type]}) — #{info[:brief]}"
            else
              "- `#{rel_name}`"
            end
          end.join("\n")
        end
      end
    end
  end
end
