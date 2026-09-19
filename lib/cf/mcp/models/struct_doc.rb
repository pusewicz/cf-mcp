# frozen_string_literal: true

module CF
  module MCP
    module Models
      class StructDoc < DocItem
        attr_accessor :members

        Member = Data.define(:declaration, :description)

        def initialize(
          name:,
          members: [],
          **kwargs
        )
          super(name:, type: :struct, **kwargs)
          @members = members || []
        end

        def to_h
          super.merge(
            members: members.map { |m| {declaration: m.declaration, description: m.description} }
          ).compact
        end

        protected

        def build_type_specific_lines
          return [] unless members && !members.empty?

          lines = ["## Members", "", "| Member | Description |", "| --- | --- |"]
          members.each do |member|
            lines << "| `#{member.declaration}` | #{member.description} |"
          end
          lines << ""
          lines
        end
      end
    end
  end
end
