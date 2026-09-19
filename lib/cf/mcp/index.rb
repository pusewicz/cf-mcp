# frozen_string_literal: true

require "singleton"

module CF
  module MCP
    class Index
      include Singleton

      attr_reader :items, :by_type, :by_category, :topic_references

      def initialize
        reset!
      end

      def reset!
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
        # Items are looked up by name, so every indexed item is expected to have one.
        name = item.name #: String
        @items[name] = item
        @by_type[item.type] << item if @by_type.key?(item.type)

        if item.category
          @by_category[item.category] ||= []
          @by_category[item.category] << item
        end

        # Build reverse reference index for topics
        build_topic_reverse_index(item) if item.is_a?(Models::TopicDoc)
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

      # `add` files each item under its own type, and every subclass fixes that type.
      def functions
        @by_type[:function] #: Array[Models::FunctionDoc]
      end

      def structs
        @by_type[:struct] #: Array[Models::StructDoc]
      end

      def enums
        @by_type[:enum] #: Array[Models::EnumDoc]
      end

      def topics
        @by_type[:topic] #: Array[Models::TopicDoc]
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
        topic_name = topic.name #: String
        topic.all_api_references.each do |ref_name|
          @topic_references[ref_name] ||= []
          @topic_references[ref_name] << topic_name unless @topic_references[ref_name].include?(topic_name)
        end
      end
    end
  end
end
