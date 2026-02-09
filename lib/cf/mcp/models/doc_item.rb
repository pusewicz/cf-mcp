# frozen_string_literal: true

module CF
  module MCP
    module Models
      class DocItem
        GITHUB_REPO = "https://github.com/RandyGaul/cute_framework"
        GITHUB_RAW_BASE = "https://raw.githubusercontent.com/RandyGaul/cute_framework/refs/heads/master"

        # Relevance scoring weights for keyword_score
        EXACT_NAME_MATCH = 1000
        PREFIX_MATCH = 500
        SUFFIX_MATCH = 400
        CONTAINS_MATCH = 100
        BRIEF_MATCH = 50
        CATEGORY_MATCH = 30
        REMARKS_MATCH = 10

        attr_accessor :name, :type, :category, :brief, :remarks, :example,
          :example_brief, :related, :source_file, :source_line

        def initialize(
          name: nil,
          type: nil,
          category: nil,
          brief: nil,
          remarks: nil,
          example: nil,
          example_brief: nil,
          related: [],
          source_file: nil,
          source_line: nil
        )
          @name = name
          @type = type
          @category = category
          @brief = brief
          @remarks = remarks
          @example = example
          @example_brief = example_brief
          @related = related || []
          @source_file = source_file
          @source_line = source_line
        end

        def matches?(query)
          return true if query.nil? || query.empty?

          keywords = query.split(/\s+/).reject(&:empty?)
          return true if keywords.empty?

          keywords.any? do |keyword|
            pattern = Regexp.new(Regexp.escape(keyword), Regexp::IGNORECASE)
            [name, brief, remarks, category].any? { |field| field&.match?(pattern) }
          end
        end

        # Returns a relevance score for ranking search results.
        # Higher scores indicate better matches.
        # Supports multi-keyword queries - scores are summed across all keywords.
        def relevance_score(query)
          return 0 if query.nil? || query.empty?

          keywords = query.split(/\s+/).reject(&:empty?)
          return 0 if keywords.empty?

          keywords.sum { |keyword| keyword_score(keyword) }
        end

        private

        def keyword_score(keyword)
          score = 0
          keyword_downcase = keyword.downcase
          name_downcase = name&.downcase || ""

          if name_downcase == keyword_downcase
            score += EXACT_NAME_MATCH
          elsif name_downcase.start_with?(keyword_downcase)
            score += PREFIX_MATCH
          elsif name_downcase.end_with?(keyword_downcase)
            score += SUFFIX_MATCH
          elsif name_downcase.include?(keyword_downcase)
            score += CONTAINS_MATCH
          end

          score += BRIEF_MATCH if brief&.downcase&.include?(keyword_downcase)
          score += CATEGORY_MATCH if category&.downcase&.include?(keyword_downcase)
          score += REMARKS_MATCH if remarks&.downcase&.include?(keyword_downcase)

          score
        end

        public

        def source_urls
          return nil unless source_file
          # Header file URLs (include/cute_xxx.h)
          header_path = "include/#{source_file}"
          raw = "#{GITHUB_RAW_BASE}/#{header_path}"
          blob = "#{GITHUB_REPO}/blob/master/#{header_path}"
          blob += "#L#{source_line}" if source_line

          # Implementation file URL (src/cute_xxx.cpp)
          impl_file = source_file.sub(/\.h$/, ".cpp")
          impl_raw = "#{GITHUB_RAW_BASE}/src/#{impl_file}"

          {raw: raw, blob: blob, impl_raw: impl_raw}
        end

        def to_h
          {
            name: name,
            type: type,
            category: category,
            brief: brief,
            remarks: remarks,
            example: example,
            example_brief: example_brief,
            related: related,
            source_file: source_file,
            source_line: source_line
          }.compact
        end

        def to_summary
          "- **#{name}** `(#{type}, #{category})` — #{brief}"
        end

        def to_text(detailed: false, index: nil)
          lines = []
          lines.concat(build_header_lines)
          lines.concat(build_description_lines)

          if detailed
            lines.concat(build_type_specific_lines)
            lines.concat(build_remarks_lines)
            lines.concat(build_example_lines)
            lines.concat(build_related_lines(index))
          end

          lines.join("\n")
        end

        protected

        def build_header_lines
          lines = []
          lines << "# #{name}"
          lines << ""
          lines << "- **Type:** #{type}"
          lines << "- **Category:** #{category}" if category
          if source_file
            urls = source_urls
            lines << "- **Source:** [include/#{source_file}](#{urls[:blob]})"
            lines << "- **Raw:** #{urls[:raw]}"
            lines << "- **Implementation:** #{urls[:impl_raw]}"
          end
          lines << ""
          lines
        end

        def build_description_lines
          lines = []
          lines << "## Description"
          lines << brief if brief
          lines << ""
          lines
        end

        def build_type_specific_lines
          [] # Override in subclasses
        end

        def build_remarks_lines
          return [] unless remarks && !remarks.empty?
          ["## Remarks", remarks, ""]
        end

        def build_example_lines
          return [] unless example && !example.empty?
          lines = ["## Example"]
          lines << example_brief if example_brief
          lines << "```c"
          lines << example
          lines << "```"
          lines << ""
          lines
        end

        def build_related_lines(index)
          return [] unless related && !related.empty?
          ["## Related", format_related_items(index), ""]
        end

        public

        def format_related_items(index)
          return related.join(", ") unless index

          related.map do |rel_name|
            info = index.brief_for(rel_name)
            if info
              "- `#{info[:name]}` (#{info[:type]}) — #{info[:brief]}"
            else
              "- `#{rel_name}`"
            end
          end.join("\n")
        end
      end
    end
  end
end
