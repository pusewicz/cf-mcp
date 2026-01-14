# frozen_string_literal: true

require_relative "doc_item"

module CF
  module MCP
    module Models
      class FunctionDoc < DocItem
        attr_accessor :signature, :parameters, :return_value

        Parameter = Data.define(:name, :description)

        def initialize(
          signature: nil,
          parameters: [],
          return_value: nil,
          **kwargs
        )
          super(type: :function, **kwargs)
          @signature = signature
          @parameters = parameters || []
          @return_value = return_value
        end

        def to_h
          super.merge(
            signature: signature,
            parameters: parameters.map { |p| {name: p.name, description: p.description} },
            return_value: return_value
          ).compact
        end

        def to_summary
          lines = ["- **#{name}** `(#{type}, #{category})` — #{brief}"]
          lines << "  `#{signature}`" if signature
          lines.join("\n")
        end

        def to_text(detailed: false, index: nil)
          lines = []
          lines << "# #{name}"
          lines << ""
          lines << "- **Type:** function"
          lines << "- **Category:** #{category}" if category
          if source_file
            urls = source_urls
            lines << "- **Source:** [include/#{source_file}](#{urls[:blob]})"
            lines << "- **Raw:** #{urls[:raw]}"
            lines << "- **Implementation:** #{urls[:impl_raw]}"
          end
          lines << ""

          if signature
            lines << "## Signature"
            lines << "```c"
            lines << signature
            lines << "```"
            lines << ""
          end

          lines << "## Description"
          lines << brief if brief
          lines << ""

          if detailed
            if parameters && !parameters.empty?
              lines << "## Parameters"
              lines << ""
              lines << "| Parameter | Description |"
              lines << "| --- | --- |"
              parameters.each do |param|
                lines << "| `#{param.name}` | #{param.description} |"
              end
              lines << ""
            end

            if return_value && !return_value.empty?
              lines << "## Return Value"
              lines << return_value
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
