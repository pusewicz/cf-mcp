# frozen_string_literal: true

module CF
  module MCP
    module Models
      class FunctionDoc < DocItem
        attr_accessor :signature, :parameters, :return_value

        Parameter = Data.define(:name, :description)

        def initialize(
          name:,
          signature: nil,
          parameters: [],
          return_value: nil,
          **kwargs
        )
          super(name:, type: :function, **kwargs)
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
          lines = build_header_lines + build_signature_lines + build_description_lines

          if detailed
            lines.concat(build_type_specific_lines)
            lines.concat(build_remarks_lines)
            lines.concat(build_example_lines)
            lines.concat(build_related_lines(index))
          end

          lines.join("\n")
        end

        protected

        def build_signature_lines
          return [] unless signature
          ["## Signature", "```c", signature, "```", ""]
        end

        def build_type_specific_lines
          build_parameters_lines + build_return_value_lines
        end

        def build_parameters_lines
          return [] unless parameters && !parameters.empty?

          ["## Parameters", "", "| Parameter | Description |", "| --- | --- |"] +
            parameters.map { |param| "| `#{param.name}` | #{param.description} |" } +
            [""]
        end

        def build_return_value_lines
          return [] unless return_value && !return_value.empty?

          ["## Return Value", return_value, ""]
        end
      end
    end
  end
end
