# frozen_string_literal: true

module CF
  module MCP
    class Parser
      DOC_BLOCK_PATTERN = %r{/\*\*.*?\*/}m
      TAG_PATTERN = /@(\w+)\s*/
      MEMBER_COMMENT_PATTERN = %r{/\*\s*@member\s+(.*?)\s*\*/}m
      ENTRY_COMMENT_PATTERN = %r{/\*\s*@entry\s+(.*?)\s*\*/}m
      CF_ENUM_PATTERN = /CF_ENUM\s*\(\s*(\w+)\s*,\s*([^)]*)\)/
      SIGNATURE_CLEANUP = /\b(CF_API|CF_CALL|CF_INLINE)\b\s*/
      END_MARKER_PATTERN = %r{//\s*@end|/\*\s*@end\s*\*/}

      def parse_file(path)
        content = File.read(path)
        source_file = File.basename(path)
        line_offsets = build_line_offsets(content)
        items = [] #: Array[Models::DocItem]

        # Find all documentation blocks with their positions
        content.scan(%r{(/\*\*.*?\*/)(.*?)(?=/\*\*|\z)}m) do |doc_block, following_content|
          # Get the position of the match to calculate line number
          match = Regexp.last_match || raise("scan yielded without a match")
          source_line = line_for_position(match.begin(0), line_offsets)
          item = parse_doc_block(doc_block, following_content.strip, source_file, source_line)
          items << item if item
        end

        items
      end

      def parse_directory(path)
        Dir.glob(File.join(path, "**/*.h")).flat_map do |header_file|
          warn "Parsing #{header_file}" if $stderr.isatty
          parse_file(header_file)
        end
      end

      private

      # Build an array of byte positions where each line starts
      def build_line_offsets(content)
        offsets = [0]
        content.each_char.with_index do |char, index|
          offsets << index + 1 if char == "\n"
        end
        offsets
      end

      # Convert a byte position to a 1-based line number
      def line_for_position(position, line_offsets)
        # Binary search to find the line containing this position
        line_offsets.bsearch_index { |offset| offset > position } || line_offsets.size
      end

      def parse_doc_block(doc_block, following_content, source_file, source_line = nil)
        tags = extract_tags(doc_block)
        return nil if tags.empty?

        type = determine_type(tags)
        return nil unless type

        case type
        when :function
          parse_function(tags, following_content, source_file, source_line)
        when :struct
          parse_struct(tags, following_content, source_file, source_line)
        when :enum
          parse_enum(tags, following_content, source_file, source_line)
        end
      end

      def extract_tags(doc_block)
        tags = {} #: Hash[Symbol, untyped]

        # Remove comment markers and clean up
        lines = doc_block.lines.map do |line|
          line.gsub(%r{^\s*/?\*+\s?}, "").gsub(%r{\s*\*+/\s*$}, "")
        end

        # A tag starts on a line containing @tag and runs until the next one.
        lines.slice_before { |line| TAG_PATTERN.match?(line) }.each do |tag_lines|
          first_line = tag_lines.fetch(0)

          # Text before the first tag has no tag to belong to
          tag = first_line[TAG_PATTERN, 1]
          next unless tag

          remaining = first_line.sub(TAG_PATTERN, "").strip
          save_tag(tags, tag, [remaining, *tag_lines.drop(1)].join("\n").strip)
        end

        tags
      end

      def save_tag(tags, tag, content)
        case tag
        when "param"
          tags[:params] ||= []
          # Parse "param_name description" format
          if (match = /^(\w+)\s+(.*)$/m.match(content))
            tags[:params] << {name: match[1], description: match[2].strip}
          end
        when "related"
          # Filter out comment artifacts like "/" or "*/"
          tags[:related] = content.split(/\s+/).reject { |s| s.empty? || s.match?(%r{^[/*]+$}) }
        else
          tags[tag.to_sym] = content
        end
      end

      def determine_type(tags)
        return :function if tags[:function]
        return :struct if tags[:struct]
        return :enum if tags[:enum]
        nil
      end

      def parse_function(tags, following_content, source_file, source_line = nil)
        # Extract signature from following content
        signature = extract_signature(following_content)

        Models::FunctionDoc.new(
          name: tags[:function],
          category: tags[:category],
          brief: tags[:brief],
          remarks: tags[:remarks],
          example: tags[:example],
          related: tags[:related] || [],
          source_file: source_file,
          source_line: source_line,
          signature: signature,
          parameters: (tags[:params] || []).map { |p| Models::FunctionDoc::Parameter.new(p[:name], p[:description]) },
          return_value: tags[:return]
        )
      end

      def parse_struct(tags, following_content, source_file, source_line = nil)
        # Extract members from the struct body
        members = extract_members(following_content)

        Models::StructDoc.new(
          name: tags[:struct],
          category: tags[:category],
          brief: tags[:brief],
          remarks: tags[:remarks],
          example: tags[:example],
          related: tags[:related] || [],
          source_file: source_file,
          source_line: source_line,
          members: members
        )
      end

      def parse_enum(tags, following_content, source_file, source_line = nil)
        # Extract enum entries from the #define macro
        entries = extract_enum_entries(following_content)

        Models::EnumDoc.new(
          name: tags[:enum],
          category: tags[:category],
          brief: tags[:brief],
          remarks: tags[:remarks],
          example: tags[:example],
          related: tags[:related] || [],
          source_file: source_file,
          source_line: source_line,
          entries: entries
        )
      end

      def extract_signature(content)
        # Find the first function declaration (ending with ; or {)
        signature_lines = content.lines
          # Skip empty lines and comments at the start
          .drop_while { |line| line.strip.empty? }
          # Stop at the first empty line, and at struct/enum definitions
          .take_while { |line| !line.strip.empty? && !/^typedef\s+(struct|enum)/.match?(line) && !/^#define/.match?(line) }
          # ...and just after the line that ends the declaration
          .slice_after { |line| line.include?(";") || line.include?("{") }
          .first

        return nil if signature_lines.nil? || signature_lines.empty?

        signature = signature_lines.join.strip
        # Clean up macros and normalize whitespace
        signature = signature.gsub(SIGNATURE_CLEANUP, "")
        signature = signature.gsub(/\s*\{.*$/m, "").strip
        signature = signature.gsub(/;$/, "").strip
        signature.empty? ? nil : signature
      end

      def extract_members(content)
        # Find /* @member ... */ comments and the following declaration
        # Use [^/]+? to ensure we capture content (non-slash chars) before the next comment
        content.scan(%r{/\*\s*@member\s+(.*?)\s*\*/\s*([^/]+?)(?=/\*|//\s*@end|$)}m).filter_map do |description, declaration|
          decl = declaration.strip.lines.first&.strip
          next unless decl && !decl.empty?

          # Clean up the declaration (remove trailing semicolon for display)
          decl = decl.gsub(/;$/, "").strip
          Models::StructDoc::Member.new(decl, description.strip)
        end
      end

      def extract_enum_entries(content)
        # Find the #define block with CF_ENUM macros
        # Pattern: /* @entry description */ followed by CF_ENUM(NAME, VALUE)
        content.scan(%r{/\*\s*@entry\s+(.*?)\s*\*/\s*\\?\s*CF_ENUM\s*\(\s*(\w+)\s*,\s*([^)]*)\)}m).map do |description, name, value|
          # CF_ENUM(K, V) expands to CF_##K = V, so add CF_ prefix
          Models::EnumDoc::Entry.new("CF_#{name.strip}", value.strip, description.strip)
        end
      end
    end
  end
end
