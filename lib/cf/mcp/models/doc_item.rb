# frozen_string_literal: true

module CF
  module MCP
    module Models
      class DocItem
        GITHUB_REPO = "https://github.com/RandyGaul/cute_framework"
        GITHUB_RAW_BASE = "https://raw.githubusercontent.com/RandyGaul/cute_framework/refs/heads/master"

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

          pattern = Regexp.new(Regexp.escape(query), Regexp::IGNORECASE)
          [name, brief, remarks, category].any? { |field| field&.match?(pattern) }
        end

        # Returns a relevance score for ranking search results.
        # Higher scores indicate better matches.
        def relevance_score(query)
          return 0 if query.nil? || query.empty?

          score = 0
          query_downcase = query.downcase
          name_downcase = name&.downcase || ""

          # Exact name match (highest priority)
          if name_downcase == query_downcase
            score += 1000
          # Name starts with query (prefix match)
          elsif name_downcase.start_with?(query_downcase)
            score += 500
          # Name ends with query (suffix match, e.g., "make_app" matches "cf_make_app")
          elsif name_downcase.end_with?(query_downcase)
            score += 400
          # Name contains query
          elsif name_downcase.include?(query_downcase)
            score += 100
          end

          # Brief contains query
          score += 50 if brief&.downcase&.include?(query_downcase)

          # Category contains query
          score += 30 if category&.downcase&.include?(query_downcase)

          # Remarks contains query
          score += 10 if remarks&.downcase&.include?(query_downcase)

          score
        end

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
          lines << "## Description"
          lines << brief if brief
          lines << ""

          if detailed
            if remarks && !remarks.empty?
              lines << "## Remarks"
              lines << remarks
              lines << ""
            end

            if example && !example.empty?
              lines << "## Example"
              lines << example_brief if example_brief
              lines << "```c"
              lines << example
              lines << "```"
              lines << ""
            end

            if related && !related.empty?
              lines << "## Related"
              lines << format_related_items(index)
              lines << ""
            end
          end

          lines.join("\n")
        end

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
