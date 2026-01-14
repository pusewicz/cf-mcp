# frozen_string_literal: true

module CF
  module MCP
    class Index
      attr_reader :items, :by_type, :by_category, :topic_references

      def initialize
        @items = {}
        @by_type = {
          function: [],
          struct: [],
          enum: [],
          topic: []
        }
        @by_category = {}
        @topic_references = {}
      end

      def add(item)
        @items[item.name] = item
        @by_type[item.type] << item if @by_type.key?(item.type)

        if item.category
          @by_category[item.category] ||= []
          @by_category[item.category] << item
        end

        # Build reverse reference index for topics
        build_topic_reverse_index(item) if item.type == :topic
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

      def topics
        @by_type[:topic]
      end

      def topics_ordered
        topics.sort_by { |t| t.reading_order || Float::INFINITY }
      end

      def topics_for(api_name)
        (@topic_references[api_name] || []).map { |name| find(name) }.compact
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
          topics: @by_type[:topic].size,
          categories: @by_category.size
        }
      end

      private

      def all_items
        @items.values
      end

      def build_topic_reverse_index(topic)
        topic.all_api_references.each do |ref_name|
          @topic_references[ref_name] ||= []
          @topic_references[ref_name] << topic.name unless @topic_references[ref_name].include?(topic.name)
        end
      end
    end
  end
end
