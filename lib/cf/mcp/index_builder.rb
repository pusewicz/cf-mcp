# frozen_string_literal: true

require "open3"

module CF
  module MCP
    class IndexBuilder
      DEFAULT_HEADERS_PATH = File.expand_path("~/Work/GitHub/pusewicz/cute_framework/include")

      attr_reader :headers_path, :revision

      def initialize(root: nil, download: false)
        @headers_path = resolve_headers_path(root: root, download: download)
      end

      def build
        parser = Parser.new
        index = Index.instance
        index.reset!

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
        if root
          @revision = detect_git_revision(root)
          nested_include = File.join(root, "include")
          return File.directory?(nested_include) ? nested_include : root
        end

        if (env_path = ENV["CF_HEADERS_PATH"])
          @revision = detect_git_revision(env_path)
          return env_path
        end

        if download
          warn "Downloading Cute Framework headers from GitHub..."
          downloader = Downloader.new
          path = downloader.download_and_extract
          @revision = downloader.sha
          warn "Downloaded headers to: #{path}"
          return path
        end

        @revision = detect_git_revision(DEFAULT_HEADERS_PATH)
        DEFAULT_HEADERS_PATH
      end

      # Detects the current git commit SHA for a local Cute Framework checkout.
      # `path` may be the repo root or any subdirectory within it (e.g. include/) -
      # git walks up to find the enclosing repository either way.
      def detect_git_revision(path)
        return nil unless File.directory?(path)

        stdout, _stderr, status = Open3.capture3("git", "-C", path, "rev-parse", "--short", "HEAD")
        return nil unless status.success?

        sha = stdout.strip
        sha.empty? ? nil : sha
      rescue Errno::ENOENT
        nil
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
