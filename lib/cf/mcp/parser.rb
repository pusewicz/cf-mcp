# frozen_string_literal: true

require_relative "models/function_doc"
require_relative "models/struct_doc"
require_relative "models/enum_doc"

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
        items = []

        # Find all documentation blocks
        content.scan(%r{(/\*\*.*?\*/)(.*?)(?=/\*\*|\z)}m) do |doc_block, following_content|
          item = parse_doc_block(doc_block, following_content.strip, source_file)
          items << item if item
        end

        items
      end

      def parse_directory(path)
        items = []
        Dir.glob(File.join(path, "**/*.h")).each do |header_file|
          items.concat(parse_file(header_file))
        end
        items
      end

      private

      def parse_doc_block(doc_block, following_content, source_file)
        tags = extract_tags(doc_block)
        return nil if tags.empty?

        type = determine_type(tags)
        return nil unless type

        case type
        when :function
          parse_function(tags, following_content, source_file)
        when :struct
          parse_struct(tags, following_content, source_file)
        when :enum
          parse_enum(tags, following_content, source_file)
        end
      end

      def extract_tags(doc_block)
        tags = {}

        # Remove comment markers and clean up
        lines = doc_block.lines.map do |line|
          line.gsub(%r{^\s*/?\*+\s?}, "").gsub(%r{\s*\*+/\s*$}, "")
        end

        current_tag = nil
        current_content = []

        lines.each do |line|
          if line =~ TAG_PATTERN
            # Save previous tag
            if current_tag
              save_tag(tags, current_tag, current_content.join("\n").strip)
            end

            current_tag = ::Regexp.last_match(1)
            remaining = line.sub(TAG_PATTERN, "").strip
            current_content = [remaining]
          elsif current_tag
            current_content << line
          end
        end

        # Save last tag
        if current_tag
          save_tag(tags, current_tag, current_content.join("\n").strip)
        end

        tags
      end

      def save_tag(tags, tag, content)
        case tag
        when "param"
          tags[:params] ||= []
          # Parse "param_name description" format
          if content =~ /^(\w+)\s+(.*)$/m
            tags[:params] << {name: ::Regexp.last_match(1), description: ::Regexp.last_match(2).strip}
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

      def parse_function(tags, following_content, source_file)
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
          signature: signature,
          parameters: (tags[:params] || []).map { |p| Models::FunctionDoc::Parameter.new(p[:name], p[:description]) },
          return_value: tags[:return]
        )
      end

      def parse_struct(tags, following_content, source_file)
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
          members: members
        )
      end

      def parse_enum(tags, following_content, source_file)
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
          entries: entries
        )
      end

      def extract_signature(content)
        # Find the first function declaration (ending with ; or {)
        lines = content.lines
        signature_lines = []

        lines.each do |line|
          # Skip empty lines and comments at the start
          next if line.strip.empty? && signature_lines.empty?
          break if line.strip.empty? && !signature_lines.empty?

          # Stop at struct/enum definitions
          break if /^typedef\s+(struct|enum)/.match?(line)
          break if /^#define/.match?(line)

          signature_lines << line
          break if line.include?(";") || line.include?("{")
        end

        return nil if signature_lines.empty?

        signature = signature_lines.join.strip
        # Clean up macros and normalize whitespace
        signature = signature.gsub(SIGNATURE_CLEANUP, "")
        signature = signature.gsub(/\s*\{.*$/m, "").strip
        signature = signature.gsub(/;$/, "").strip
        signature.empty? ? nil : signature
      end

      def extract_members(content)
        members = []

        # Find /* @member ... */ comments and the following declaration
        # Use [^/]+? to ensure we capture content (non-slash chars) before the next comment
        content.scan(%r{/\*\s*@member\s+(.*?)\s*\*/\s*([^/]+?)(?=/\*|//\s*@end|$)}m) do |description, declaration|
          decl = declaration.strip.lines.first&.strip
          next unless decl && !decl.empty?

          # Clean up the declaration (remove trailing semicolon for display)
          decl = decl.gsub(/;$/, "").strip
          members << Models::StructDoc::Member.new(decl, description.strip)
        end

        members
      end

      def extract_enum_entries(content)
        entries = []

        # Find the #define block with CF_ENUM macros
        # Pattern: /* @entry description */ followed by CF_ENUM(NAME, VALUE)
        content.scan(%r{/\*\s*@entry\s+(.*?)\s*\*/\s*\\?\s*CF_ENUM\s*\(\s*(\w+)\s*,\s*([^)]*)\)}m) do |description, name, value|
          entries << Models::EnumDoc::Entry.new(name.strip, value.strip, description.strip)
        end

        entries
      end
    end
  end
end
