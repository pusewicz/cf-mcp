# frozen_string_literal: true

require_relative "doc_item"
require_relative "tabular_doc"

module CF
  module MCP
    module Models
      class EnumDoc < DocItem
        include TabularDoc

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

        protected

        def build_type_specific_lines
          return [] unless entries && !entries.empty?

          build_table(heading: "Values", headers: ["Name", "Value", "Description"], rows: entries) { |e|
            "`#{e.name}` | #{e.value} | #{e.description}"
          }
        end
      end
    end
  end
end
