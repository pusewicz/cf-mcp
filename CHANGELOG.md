# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- SHA-based caching for downloaded Cute Framework headers - checks GitHub API for latest commit SHA before downloading to avoid redundant fetches
- GitHub API client with optional GITHUB_TOKEN support for higher rate limits (5000/hr vs 60/hr unauthenticated)
- Metadata tracking (.cf-mcp-sha file) stores downloaded version SHA for cache validation

### Changed

- Downloader uses commit-specific archive URLs (e.g., /archive/abc1234.zip) instead of always downloading master branch
- Download process now checks for updates by comparing stored SHA with latest GitHub commit

## [0.16.2] - 2026-01-31

### Fixed

- Enum entries now correctly prefixed with `CF_` (e.g., `CF_KEY_SPACE` instead of `KEY_SPACE`) to match the CF_ENUM macro expansion

## [0.16.1] - 2026-01-31

### Fixed

- Fix broken logo image path in dashboard (use favicon.svg instead of non-existent logo.svg)

### Changed

- Add workflow_dispatch trigger to fly-deploy.yml for manual deployments

## [0.16.0] - 2026-01-26

### Changed

- **Refactored tool loading with Index singleton** - Index is now a singleton, eliminating duplicate schema definitions and simplifying tool initialization
- Tool classes now use `Index.instance.categories` directly in schema definitions instead of requiring runtime configuration
- Removed `TOOLS` constant and `configure_tool_schemas` method from Server
- Tools use autoload for lazy loading, ensuring they see populated categories at load time

## [0.15.5] - 2026-01-26

### Changed

- Complete favicon overhaul using realfavicongenerator for proper cross-browser support
- Added SVG favicon, apple-touch-icon, and web app manifest
- MCP server icons now use favicon.svg and favicon-96x96.png

## [0.15.4] - 2026-01-26

### Fixed

- Include all favicon files in gem manifest

## [0.15.3] - 2026-01-26

### Fixed

- Landing page now serves HTML by default for GET requests without an explicit `Accept: application/json` header, fixing W3C validator compatibility

### Changed

- Improved favicon support with proper sizes (16x16, 32x32, 96x96) and SVG fallback

## [0.15.2] - 2026-01-26

### Added

- Favicon support (48x48 PNG) served at `/favicon.png` and `/favicon.ico`
- Favicon link tag in HTML template for browser tab icons

## [0.15.1] - 2026-01-26

### Added

- PNG icon (262x218) as additional server icon option

## [0.15.0] - 2026-01-26

### Changed

- **BREAKING:** Removed `cf_` prefix from all tool names (e.g., `cf_search` is now `search`)
- **BREAKING:** Removed `CF: ` prefix from all tool titles (e.g., `CF: Search` is now `Search`)
- Renamed `CLAUDE.md` to `AGENTS.md` with `CLAUDE.md` referencing it

### Added

- MCP Inspector usage instructions in README

## [0.14.3] - 2026-01-26

### Changed

- Added `sizes: ["any"]` to server icon metadata to comply with MCP icon specification

## [0.14.2] - 2026-01-26

### Added

- Logo icon displayed in the web dashboard title

## [0.14.1] - 2026-01-26

### Added

- Server metadata: title ("Cute Framework MCP"), website URL, and logo icon
- Cute Framework logo served as static asset at `/logo.svg`
- Protocol version output in MCP server info

## [0.13.1] - 2026-01-16

### Added

- RBS type signatures for all classes in `sig/cf/mcp.rbs`
- `rbs` gem added to development dependencies
- `rake rbs` task for validating RBS signatures (included in default rake task)

### Changed

- Removed title from web UI landing page

## [0.13.0] - 2026-01-16

### Changed

- Refactored server to use single `Server` class (merged `HTTPServer` functionality)
- Updated MCP protocol version to 2024-11-05

## [0.12.1] - 2026-01-14

### Changed

- Refactored tool classes to use shared `ResponseHelpers` module, removing duplicate code
- Extracted `IndexBuilder` class to consolidate index building logic from CLI and HTTPServer
- Extracted `SearchResultFormatter` module for consistent search result formatting
- Simplified model `to_text()` methods using template method pattern in `DocItem` base class

## [0.12.0] - 2026-01-14

### Changed

- Renamed `CombinedServer` to `HTTPServer` for clarity
- Updated config.ru to use the new `HTTPServer` class

### Removed

- SSE transport endpoint (HTTP streamable transport is now the only HTTP option)

## [0.10.1] - 2026-01-14

### Added

- `--host` CLI option for binding address (defaults to `0.0.0.0`)
- `CombinedServer.build_rack_app` class method for shared boot logic

### Changed

- Unified boot process: config.ru and CLI now share the same initialization logic
- Simplified config.ru to a single line using `CombinedServer.build_rack_app`

### Removed

- `Procfile` (Fly.io uses config.ru directly)

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

[0.16.2]: https://github.com/pusewicz/cf-mcp/compare/v0.16.1...v0.16.2
[0.16.1]: https://github.com/pusewicz/cf-mcp/compare/v0.16.0...v0.16.1
[0.16.0]: https://github.com/pusewicz/cf-mcp/compare/v0.15.5...v0.16.0
[0.15.5]: https://github.com/pusewicz/cf-mcp/compare/v0.15.4...v0.15.5
[0.15.4]: https://github.com/pusewicz/cf-mcp/compare/v0.15.3...v0.15.4
[0.15.3]: https://github.com/pusewicz/cf-mcp/compare/v0.15.2...v0.15.3
[0.15.2]: https://github.com/pusewicz/cf-mcp/compare/v0.15.1...v0.15.2
[0.15.1]: https://github.com/pusewicz/cf-mcp/compare/v0.15.0...v0.15.1
[0.15.0]: https://github.com/pusewicz/cf-mcp/compare/v0.14.3...v0.15.0
[0.14.3]: https://github.com/pusewicz/cf-mcp/compare/v0.14.2...v0.14.3
[0.14.2]: https://github.com/pusewicz/cf-mcp/compare/v0.14.1...v0.14.2
[0.14.1]: https://github.com/pusewicz/cf-mcp/compare/v0.14.0...v0.14.1
[0.13.1]: https://github.com/pusewicz/cf-mcp/compare/v0.13.0...v0.13.1
[0.13.0]: https://github.com/pusewicz/cf-mcp/compare/v0.12.1...v0.13.0
[0.12.1]: https://github.com/pusewicz/cf-mcp/compare/v0.12.0...v0.12.1
[0.12.0]: https://github.com/pusewicz/cf-mcp/compare/v0.10.1...v0.12.0
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
