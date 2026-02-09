# frozen_string_literal: true

module CF
  module MCP
    module Models
      module TabularDoc
        def build_table(heading:, headers:, rows:)
          return [] if rows.empty?

          lines = []
          lines << "## #{heading}"
          lines << ""
          lines << "| #{headers.join(" | ")} |"
          lines << "| #{headers.map { "---" }.join(" | ")} |"
          rows.each { |row| lines << "| #{yield(row)} |" }
          lines << ""
          lines
        end
      end
    end
  end
end
