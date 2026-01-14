# frozen_string_literal: true

module CF
  module MCP
    class Index
      attr_reader :items, :by_type, :by_category

      def initialize
        @items = {}
        @by_type = {
          function: [],
          struct: [],
          enum: []
        }
        @by_category = {}
      end

      def add(item)
        @items[item.name] = item
        @by_type[item.type] << item if @by_type.key?(item.type)

        if item.category
          @by_category[item.category] ||= []
          @by_category[item.category] << item
        end
      end

      def find(name)
        @items[name]
      end

      def brief_for(name)
        item = find(name)
        return nil unless item
        {name: item.name, type: item.type, brief: item.brief}
      end

      def search(query, type: nil, category: nil, limit: 20)
        results = all_items

        # Filter by type
        if type
          type_sym = type.to_sym
          results = results.select { |item| item.type == type_sym }
        end

        # Filter by category
        if category
          results = results.select { |item| item.category == category }
        end

        # Filter by query and sort by relevance
        if query && !query.empty?
          results = results
            .select { |item| item.matches?(query) }
            .sort_by { |item| -item.relevance_score(query) }
        end

        results.take(limit)
      end

      def functions
        @by_type[:function]
      end

      def structs
        @by_type[:struct]
      end

      def enums
        @by_type[:enum]
      end

      def categories
        @by_category.keys.sort
      end

      def items_in_category(category)
        @by_category[category] || []
      end

      def size
        @items.size
      end

      def stats
        {
          total: @items.size,
          functions: @by_type[:function].size,
          structs: @by_type[:struct].size,
          enums: @by_type[:enum].size,
          categories: @by_category.size
        }
      end

      private

      def all_items
        @items.values
      end
    end
  end
end
