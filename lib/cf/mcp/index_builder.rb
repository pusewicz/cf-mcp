# frozen_string_literal: true

require_relative "parser"
require_relative "topic_parser"
require_relative "index"
require_relative "downloader"

module CF
  module MCP
    class IndexBuilder
      DEFAULT_HEADERS_PATH = File.expand_path("~/Work/GitHub/pusewicz/cute_framework/include")

      attr_reader :headers_path

      def initialize(root: nil, download: false)
        @headers_path = resolve_headers_path(root: root, download: download)
      end

      def build
        parser = Parser.new
        index = Index.new

        parser.parse_directory(headers_path).each do |item|
          index.add(item)
        end

        # Parse topics if available
        topics_path = find_topics_path(headers_path)
        if topics_path && File.directory?(topics_path)
          topic_parser = TopicParser.new
          topic_parser.parse_directory(topics_path).each do |topic|
            refine_topic_references(topic, index)
            index.add(topic)
          end
          yield(:topics_indexed, topics_path, index.stats[:topics]) if block_given?
        end

        index
      end

      def valid?
        File.directory?(headers_path)
      end

      private

      def resolve_headers_path(root:, download:)
        return root if root
        return ENV["CF_HEADERS_PATH"] if ENV["CF_HEADERS_PATH"]

        # :nocov:
        if download
          warn "Downloading Cute Framework headers from GitHub..."
          downloader = Downloader.new
          path = downloader.download_and_extract
          warn "Downloaded headers to: #{path}"
          return path
        end
        # :nocov:

        DEFAULT_HEADERS_PATH
      end

      def find_topics_path(headers_path)
        # If headers_path is .../cute_framework/include, topics is at .../cute_framework/docs/topics
        base = File.dirname(headers_path)
        topics_path = File.join(base, "docs", "topics")
        return topics_path if File.directory?(topics_path)

        # Alternative: topics directly under headers parent
        topics_path = File.join(base, "topics")
        return topics_path if File.directory?(topics_path)

        nil
      end

      def refine_topic_references(topic, index)
        # Move items from struct_references to enum_references if they're actually enums
        topic.struct_references.dup.each do |ref|
          item = index.find(ref)
          next unless item

          if item.type == :enum
            topic.struct_references.delete(ref)
            topic.enum_references << ref unless topic.enum_references.include?(ref)
          end
        end
      end
    end
  end
end
