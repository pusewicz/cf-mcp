# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.10.1] - 2026-01-14

### Added

- `--host` CLI option for binding address (defaults to `0.0.0.0`)

### Changed

- Unified boot process: Procfile now uses `cf-mcp combined --download` instead of rackup

### Removed

- `config.ru` (no longer needed, CLI handles all server modes)

## [0.10.0] - 2026-01-14

### Added

- Multi-keyword search support: queries like "draw circle rectangle" now match items containing any keyword
- Items matching more keywords rank higher in search results

## [0.9.3] - 2026-01-14

### Added

- Claude Code slash commands for version bumping and releases
- Documentation for changelog and slash commands in CLAUDE.md

### Changed

- Include CHANGELOG.md in gem manifest

## [0.9.2] - 2026-01-14

### Added

- Changelog display in the web UI

## [0.9.1] - 2026-01-14

### Changed

- Version bump release

## [0.9.0] - 2026-01-14

### Changed

- Rewrote web UI with Preact for better interactivity
- Form now remembers the last search value
- Refactored internal code structure

## [0.8.0] - 2026-01-14

### Changed

- Downloader now caches headers per version, avoiding re-downloads

## [0.7.0] - 2026-01-14

### Added

- Added topics/categories display in search results
- Added links to source code in documentation output

## [0.6.0] - 2026-01-14

### Added

- New `cf_find_related` tool to find related functions, structs, and enums
- New `cf_member_search` tool to search struct/enum members
- New `cf_parameter_search` tool to search function parameters

## [0.5.0] - 2026-01-14

### Changed

- Search results now sorted by relevance score

## [0.4.0] - 2026-01-14

### Changed

- Extracted CSS and JavaScript assets to separate template files

## [0.3.0] - 2026-01-14

### Changed

- Improved tool output formatting for better readability

## [0.2.0] - 2026-01-14

### Added

- Tool explorer web interface for testing MCP tools interactively

## [0.1.3] - 2026-01-14

### Added

- Combined server mode (`cf-mcp combined`) with SSE, HTTP, and web UI
- Fly.io deployment configuration

## [0.1.0] - 2026-01-14

### Added

- Initial release
- MCP server with STDIO, HTTP, and SSE modes
- Header file parser for Cute Framework documentation
- In-memory search index with relevance scoring
- GitHub header downloader with `--download` flag
- Six MCP tools:
  - `cf_search` - Search all documentation types
  - `cf_search_functions` - Search functions
  - `cf_search_structs` - Search structs
  - `cf_search_enums` - Search enums
  - `cf_list_category` - List items by category
  - `cf_get_details` - Get full documentation by name

[0.10.1]: https://github.com/pusewicz/cf-mcp/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/pusewicz/cf-mcp/compare/v0.9.3...v0.10.0
[0.9.3]: https://github.com/pusewicz/cf-mcp/compare/v0.9.2...v0.9.3
[0.9.2]: https://github.com/pusewicz/cf-mcp/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/pusewicz/cf-mcp/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/pusewicz/cf-mcp/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/pusewicz/cf-mcp/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/pusewicz/cf-mcp/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/pusewicz/cf-mcp/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/pusewicz/cf-mcp/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/pusewicz/cf-mcp/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/pusewicz/cf-mcp/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/pusewicz/cf-mcp/compare/v0.1.3...v0.2.0
[0.1.3]: https://github.com/pusewicz/cf-mcp/compare/v0.1.0...v0.1.3
[0.1.0]: https://github.com/pusewicz/cf-mcp/releases/tag/v0.1.0
