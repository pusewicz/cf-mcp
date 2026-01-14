# frozen_string_literal: true

module CF
  module MCP
    module Tools
      module SearchResultFormatter
        def format_search_results(results, query:, type_label:, limit:, details_tip:, filter_suggestion: nil)
          if results.empty?
            # Use plural form for "no results" message (e.g., "No functions found")
            plural_label = type_label.sub(/\(s\)$/, "s")
            return "No #{plural_label} found for '#{query}'"
          end

          formatted = results.map(&:to_summary).join("\n")

          header = if results.size >= limit
            "Found #{results.size} #{type_label} (limit reached, more may exist):"
          else
            "Found #{results.size} #{type_label}:"
          end

          footer = "\n\n#{details_tip}"
          footer += "\n#{filter_suggestion}" if results.size >= limit && filter_suggestion

          "#{header}\n\n#{formatted}#{footer}"
        end
      end
    end
  end
end
