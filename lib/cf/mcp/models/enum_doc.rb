# frozen_string_literal: true

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

        protected

        def build_type_specific_lines
          return [] unless entries && !entries.empty?

          lines = []
          lines << "## Values"
          lines << ""
          lines << "| Name | Value | Description |"
          lines << "| --- | --- | --- |"
          entries.each do |entry|
            lines << "| `#{entry.name}` | #{entry.value} | #{entry.description} |"
          end
          lines << ""
          lines
        end
      end
    end
  end
end
