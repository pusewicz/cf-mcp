# frozen_string_literal: true

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
          lines.concat(build_header_lines)
          lines.concat(build_signature_lines)
          lines.concat(build_description_lines)

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
          lines = []

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

          lines
        end
      end
    end
  end
end
