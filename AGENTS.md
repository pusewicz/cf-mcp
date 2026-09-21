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

# Validate signatures, type check with Steep, run tests under the runtime type checker
rake rbs

# Run tests, lint, type check, and generate manifest (default task)
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

# Cache the parsed docs (~/.cache/cf-mcp/index.bin); re-run to pick up changes
cf-mcp index --root ~/Work/GitHub/pusewicz/cute_framework

# Every MCP tool is also a command (flags after the command belong to the tool)
cf-mcp search sprite --type function --limit 5
cf-mcp get_details CF_Sprite
```

Tool commands read the cache and rebuild it when the headers change. A tool's name is listed in `CLI::TOOL_COMMANDS` because naming a tool class loads it, and `SearchTool`/`ListCategory` bake the index's categories into their schema at load time: the index must be filled first. That is also why `CLI#take_source_options` pulls `--root`/`--download` out of a tool command's arguments before the tool's own flags (which come from its schema) are parsed.

## Architecture

```
lib/cf/mcp/
├── cli.rb              # CLI: stdio/http/index and one command per tool
├── tool_command.rb     # Runs an MCP tool as a command, generated from its input schema
├── server.rb           # MCP server setup, Server and HTTPServer classes
├── parser.rb           # Header file parser (extracts @function, @struct, @enum docs)
├── index.rb            # In-memory search index with relevance scoring
├── index_cache.rb      # On-disk cache of the parsed index, rebuilt when headers change
├── downloader.rb       # GitHub header downloader with ZIP extraction
├── models/
│   ├── doc_item.rb     # Base model with search/relevance scoring
│   ├── function_doc.rb # FunctionDoc with signature, params, return
│   ├── struct_doc.rb   # StructDoc with members
│   └── enum_doc.rb     # EnumDoc with entries
├── tools/
│   ├── search_tool.rb      # search - search all types with optional type/category filters
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

**Tools** - MCP tools for documentation access:
- `search` - Search all types with optional `type` and `category` filters
- `list_category` - List items by category
- `get_details` - Full documentation by exact name

## Code Style

Uses Standard Ruby for linting (configured in `.standard.yml`). Target Ruby version is 3.3+.

## Type Checking

Signatures are hand-written RBS in `sig/`, one file per `lib/` file. Every method, attribute and constant needs one; CI fails otherwise. `bin/setup` (or `bundle exec rbs collection install`) installs the RBS collection that Steep and the tests load.

```bash
rake rbs            # all three checks below
rake rbs:validate   # rbs validate: are the signatures well-formed?
rake rbs:steep      # steep check: does lib/ agree with them?
rake rbs:test       # the test suite under RBS's runtime checker
```

Each check catches something the others can't:

- **Steep** (`Steepfile`) checks `lib/` against `sig/` and fails on any `def` without a signature.
- **`test/cf/mcp/signatures_test.rb`** checks by reflection that everything declared exists and everything defined in `lib/` is declared. It covers `attr_*` (Steep doesn't treat those as definitions) and stale declarations (which Steep can't report reliably).
- **`rake rbs:test`** runs the suite with `RBS_TEST_TARGET='CF::MCP::*'`, so signatures are checked against real runtime values, not just against the code.

`sig-stubs/` holds hand-written stubs for gems that ship no RBS (`mcp`, `rackup`, `rubyzip`); keep them to the APIs `lib/` actually calls. It also narrows three core signatures (`Kernel#__dir__`, `String#scan`, `MatchData#begin`) that RBS core types more loosely than this code needs; each file says why. Neither `sig/` nor `sig-stubs/` is packaged in the gem (see `rake manifest`).

Things to know:

- `String#scan` is narrowed to yield up to three String captures, on the assumption that every pattern passed to it has only mandatory groups. Nothing checks that assumption, so keep optional groups (`(a)?`) out of `scan` patterns, or read them another way.
- Rack signatures come from the RBS collection and describe rack 2.2; the gem runs on rack 3.
- Prefer code whose types Steep can infer over casts: build arrays with `filter_map`/`map` or from a non-empty literal, use `line[re, 1]` or `re.match(line)` for captures, and `|| raise(...)` for a nilable value that must exist. An unavoidable empty literal takes a type comment, e.g. `items = [] #: Array[Models::DocItem]`.

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

See `cf-mcp.gemspec` for runtime and development dependencies, and `Gemfile.lock` for pinned versions.

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
