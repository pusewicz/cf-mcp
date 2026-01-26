# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CF::MCP is a Ruby gem that implements an MCP (Model Context Protocol) server for the Cute Framework, a C/C++ 2D game framework. It indexes header files, extracts documentation from comments, and provides search functionality for functions, structs, and enums.

## Commands

```bash
# Install dependencies
bin/setup

# Run all tests
rake test

# Run a single test file
ruby -Ilib:test test/cf/mcp/parser_test.rb

# Run a specific test method
ruby -Ilib:test test/cf/mcp/parser_test.rb --name test_parse_function_doc

# Lint code with Standard Ruby
rake standard

# Auto-fix linting issues
rake standard:fix

# Run tests, lint, and generate manifest (default task)
rake

# Start interactive console
bin/console

# Install gem locally
bundle exec rake install

# Create git tag for current version
rake tag

# Create tag and push to origin
rake release:tag

# Release to RubyGems (creates tag, builds gem, pushes)
rake release
```

## CLI Usage

```bash
# STDIO mode (for Claude Desktop integration)
cf-mcp stdio --root ~/Work/GitHub/pusewicz/cute_framework

# HTTP mode (web UI at /, MCP endpoint at /http, port 9292)
cf-mcp http --port 9292 --root /path/to/cute_framework

# Download headers from GitHub automatically
cf-mcp stdio --download
```

## Architecture

```
lib/cf/mcp/
├── cli.rb              # CLI with stdio/http modes
├── server.rb           # MCP server setup, Server and HTTPServer classes
├── parser.rb           # Header file parser (extracts @function, @struct, @enum docs)
├── index.rb            # In-memory search index with relevance scoring
├── downloader.rb       # GitHub header downloader with ZIP extraction
├── models/
│   ├── doc_item.rb     # Base model with search/relevance scoring
│   ├── function_doc.rb # FunctionDoc with signature, params, return
│   ├── struct_doc.rb   # StructDoc with members
│   └── enum_doc.rb     # EnumDoc with entries
├── tools/
│   ├── search_tool.rb      # search - search all types
│   ├── search_functions.rb # search_functions
│   ├── search_structs.rb   # search_structs
│   ├── search_enums.rb     # search_enums
│   ├── list_category.rb    # list_category
│   └── get_details.rb      # get_details - full docs by name
└── templates/          # Web UI for HTTP mode
    ├── index.erb
    ├── style.css
    └── script.js
```

## Key Components

**Parser** - Extracts documentation from C headers using comment patterns:
- `/** ... */` doc blocks with `@function`, `@struct`, `@enum`
- Tags: `@brief`, `@param`, `@return`, `@category`, `@remarks`, `@example`, `@related`
- Member comments: `/* @member description */`
- Enum entries: `/* @entry description */ CF_ENUM(NAME, value)`

**Index** - In-memory search with relevance scoring:
- Exact name match = 1000 points
- Prefix match = 500, suffix = 400, contains = 100
- Brief/category/remarks matches add points

**Tools** - Six MCP tools for documentation access:
- `search` - Search all types with filtering
- `search_functions`, `search_structs`, `search_enums` - Type-specific search
- `list_category` - List items by category
- `get_details` - Full documentation by exact name

## Code Style

Uses Standard Ruby for linting (configured in `.standard.yml`). Target Ruby version is 3.2+.

## Testing

```bash
# Test files in test/cf/mcp/
parser_test.rb    # Parser tests with fixtures
index_test.rb     # Index search/relevance tests
models_test.rb    # DocItem model tests
server_test.rb    # Server setup tests
tools_test.rb     # Tool response tests
```

Fixtures in `test/fixtures/sample_header.h`.

## Local Development

The local Cute Framework checkout is at `~/Work/GitHub/pusewicz/cute_framework`. Use this path when testing:

```bash
cf-mcp stdio --root ~/Work/GitHub/pusewicz/cute_framework
```

## Dependencies

- `mcp` (~> 0.5) - Ruby MCP SDK
- `rack` (~> 3.0) / `rackup` (~> 2.0) / `puma` (~> 6.0) - HTTP server
- `rubyzip` (~> 2.3) - ZIP extraction for downloader

## Changelog

The project maintains a changelog in `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

When making changes:
1. Add a new entry under the current version (check `lib/cf/mcp/version.rb`)
2. Use appropriate section headers: `### Added`, `### Changed`, `### Fixed`, `### Removed`
3. Add a comparison link at the bottom: `[X.Y.Z]: https://github.com/pusewicz/cf-mcp/compare/vPREV...vX.Y.Z`

## Slash Commands

Custom Claude Code commands available in `.claude/commands/`:

- `/bump-version-patch` - Bump patch version (e.g., 1.2.3 -> 1.2.4)
- `/bump-version-minor` - Bump minor version (e.g., 1.2.3 -> 1.3.0)
- `/bump-version-major` - Bump major version (e.g., 1.2.3 -> 2.0.0)
- `/release-gem` - Prepare a release: run tests, ensure version bump, update changelog, create PR

## References

- [Ruby MCP SDK](https://github.com/modelcontextprotocol/ruby-sdk)
- [Cute Framework Docs Parser](https://raw.githubusercontent.com/RandyGaul/cute_framework/refs/heads/master/samples/docs_parser.cpp) - Reference for parsing header documentation
