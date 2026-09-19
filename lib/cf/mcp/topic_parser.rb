# frozen_string_literal: true

module CF
  module MCP
    class TopicParser
      # Pattern to match markdown links: [text](../category/name.md)
      API_LINK_PATTERN = %r{\[`?([^\]]+)`?\]\(\.\./(\w+)/(\w+)\.md\)}

      # Pattern to match topic links: [text](./topic_name.md) or [text](../topics/topic_name.md)
      TOPIC_LINK_PATTERN = %r{\[([^\]]+)\]\((?:\./|\.\./topics/)(\w+)\.md\)}

      # Pattern to match section headings
      SECTION_PATTERN = /^##\s+(.+)$/

      def parse_file(path)
        content = File.read(path)
        filename = File.basename(path, ".md")

        return nil if filename == "index"

        parse_topic(content, filename, File.basename(path))
      end

      def parse_directory(path)
        reading_order = parse_reading_order(File.join(path, "index.md"))

        Dir.glob(File.join(path, "*.md")).filter_map do |topic_file|
          next if File.basename(topic_file) == "index.md"

          topic = parse_file(topic_file)
          next unless topic

          topic.reading_order = reading_order[topic.name]
          topic
        end
      end

      def parse_reading_order(index_path)
        return {} unless File.exist?(index_path)

        content = File.read(index_path)

        # Match numbered list items with topic links; a repeated slug keeps its last position
        content.scan(/^\d+\.\s+\[([^\]]+)\]\(\.\/(\w+)\.md\)/).each_with_index.to_h do |(_title, slug), position|
          [slug, position]
        end
      end

      private

      def parse_topic(content, slug, source_file)
        extract_title(content)
        brief = extract_brief(content)
        sections = extract_sections(content)

        func_refs, struct_refs, enum_refs = extract_api_references(content)
        topic_refs = extract_topic_references(content)

        category = derive_category(slug)

        Models::TopicDoc.new(
          name: slug,
          brief: brief,
          category: category,
          content: content,
          sections: sections,
          function_references: func_refs.uniq,
          struct_references: struct_refs.uniq,
          enum_references: enum_refs.uniq,
          topic_references: topic_refs.uniq,
          source_file: source_file
        )
      end

      def extract_title(content)
        content.lines.find { |line| line.start_with?("# ") }&.sub(/^#\s+/, "")&.strip
      end

      def extract_brief(content)
        # The first paragraph that isn't a heading
        paragraph_lines = content.lines
          .reject { |line| line.start_with?("#") }
          .drop_while { |line| line.strip.empty? }
          .take_while { |line| !line.strip.empty? }
          .map(&:strip)

        # Strip markdown links but keep the text
        paragraph_lines.join(" ").gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
      end

      def extract_sections(content)
        # A section starts on a "## Title" heading and runs until the next one.
        # Text before the first heading belongs to no section.
        content.lines.slice_before { |line| SECTION_PATTERN.match?(line) }.filter_map do |section_lines|
          heading = section_lines.fetch(0)
          title = heading[SECTION_PATTERN, 1]
          next unless title

          Models::TopicDoc::Section.new(title: title.strip, content: section_lines.drop(1).join)
        end
      end

      def extract_api_references(content)
        names = content.scan(API_LINK_PATTERN).map { |_text, _category, name| name }

        func_refs, other_refs = names.partition { |name| name.start_with?("cf_") }
        # Uppercase names are likely structs or enums
        # Will be refined when cross-referenced with index
        struct_refs = other_refs.select { |name| name.start_with?("CF_") || name.match?(/^[A-Z]/) }

        [func_refs, struct_refs, []]
      end

      def extract_topic_references(content)
        content.scan(TOPIC_LINK_PATTERN).map { |_text, slug| slug }
      end

      def derive_category(slug)
        CATEGORY_MAP[slug] || slug
      end

      CATEGORY_MAP = {
        "audio" => "audio",
        "camera" => "draw",
        "collision" => "collision",
        "coroutines" => "coroutine",
        "drawing" => "draw",
        "input" => "input",
        "networking" => "net",
        "strings" => "string",
        "random_numbers" => "math",
        "application_window" => "app",
        "game_loop_and_time" => "time",
        "file_io" => "file",
        "virtual_file_system" => "file",
        "multithreading" => "thread",
        "atomics" => "atomic",
        "data_structures" => "array",
        "allocator" => "alloc",
        "emscripten" => "app",
        "ios" => "app",
        "web" => "https",
        "dear_imgui" => "imgui",
        "low_level_graphics" => "graphics",
        "renderer" => "graphics",
        "shader_compilation" => "graphics"
      }.freeze
    end
  end
end
