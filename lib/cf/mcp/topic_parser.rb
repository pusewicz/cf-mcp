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
        topics = []
        reading_order = parse_reading_order(File.join(path, "index.md"))

        Dir.glob(File.join(path, "*.md")).each do |topic_file|
          next if File.basename(topic_file) == "index.md"

          topic = parse_file(topic_file)
          if topic
            topic.reading_order = reading_order[topic.name]
            topics << topic
          end
        end

        topics
      end

      def parse_reading_order(index_path)
        return {} unless File.exist?(index_path)

        content = File.read(index_path)
        order = {}
        position = 0

        # Match numbered list items with topic links
        content.scan(/^\d+\.\s+\[([^\]]+)\]\(\.\/(\w+)\.md\)/) do |_title, slug|
          order[slug] = position
          position += 1
        end

        order
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
        lines = content.lines
        in_paragraph = false
        paragraph_lines = []

        lines.each do |line|
          next if line.start_with?("#")

          if line.strip.empty?
            break if in_paragraph
            next
          end

          in_paragraph = true
          paragraph_lines << line.strip
        end

        # Strip markdown links but keep the text
        paragraph_lines.join(" ").gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
      end

      def extract_sections(content)
        sections = []
        current_title = nil
        current_content = []

        content.lines.each do |line|
          if line =~ SECTION_PATTERN
            if current_title
              sections << Models::TopicDoc::Section.new(
                title: current_title,
                content: current_content.join
              )
            end
            current_title = ::Regexp.last_match(1).strip
            current_content = []
          elsif current_title
            current_content << line
          end
        end

        # Add last section
        if current_title
          sections << Models::TopicDoc::Section.new(
            title: current_title,
            content: current_content.join
          )
        end

        sections
      end

      def extract_api_references(content)
        func_refs = []
        struct_refs = []
        enum_refs = []

        content.scan(API_LINK_PATTERN) do |_text, _category, name|
          if name.start_with?("cf_")
            func_refs << name
          elsif name.start_with?("CF_") || name.match?(/^[A-Z]/)
            # Uppercase names are likely structs or enums
            # Will be refined when cross-referenced with index
            struct_refs << name
          end
        end

        [func_refs, struct_refs, enum_refs]
      end

      def extract_topic_references(content)
        refs = []
        content.scan(TOPIC_LINK_PATTERN) do |_text, slug|
          refs << slug
        end
        refs
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
