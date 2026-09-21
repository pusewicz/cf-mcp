# frozen_string_literal: true

require "mcp"

module CF
  module MCP
    module Tools
      # For a tool whose `category` property takes the index's categories. They are
      # read when the schema is asked for, not when the class loads, so a tool can
      # be loaded before the index is filled. The property stays open while the
      # index is empty, as a JSON Schema enum needs at least one value.
      module CategoryEnum
        def input_schema_value
          categories = Index.instance.categories
          return super if categories.empty?

          @category_schemas ||= {} #: Hash[Array[String], ::MCP::Tool::InputSchema]
          @category_schemas[categories] ||= with_categories(super.to_h, categories)
        end

        private

        def with_categories(schema, categories)
          properties = schema.fetch(:properties)
          category = properties.fetch(:category).merge(enum: categories)
          ::MCP::Tool::InputSchema.new(schema.merge(properties: properties.merge(category: category)))
        end
      end
    end
  end
end
