# frozen_string_literal: true

require_relative "doc_item"
require_relative "tabular_doc"

module CF
  module MCP
    module Models
      class StructDoc < DocItem
        include TabularDoc

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

        protected

        def build_type_specific_lines
          return [] unless members && !members.empty?

          build_table(heading: "Members", headers: ["Member", "Description"], rows: members) { |m|
            "`#{m.declaration}` | #{m.description}"
          }
        end
      end
    end
  end
end
