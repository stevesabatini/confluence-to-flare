# Changelog

All notable changes to the Confluence-to-Flare Import Tool will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-04-02

### Added
- Animated splash screen with phased entrance (logo, orbital dots, text, progress bar)
- Real loading progress bound to Confluence API tree walk
- Load time instrumentation (disk scan, API walk, transform timings stored in UserDefaults)
- Reduce Motion accessibility support for splash screen
- Early-completion handling: splash accelerates entrance when data loads faster than animation
- Feature proposals directory for documenting planned enhancements

### Fixed
- Split view divider remnant visible after closing preview panel (right panel now fully removed/re-added)

## [1.1.0] - 2026-04-01

### Added
- Native macOS desktop app (swift-app/) with SwiftUI interface
- Release note preview with inline split-view panel and live image rendering
- Persistent window size and split panel positions across launches
- App icon and deployment to /Applications
- Keychain-based credential storage in the Swift app
- `config.yaml` fallback for bootstrapping Swift app settings
- `convertForPreview` method for Confluence image preview via base64 data URLs
- Comprehensive unit tests for ContentConverter, DateParser, and FlareUpdater

### Fixed
- SwiftSoup HTML5 normalization corrupting MadCap Flare XML (namespace casing, XML declarations)
- Image width loss caused by SwiftSoup dropping `ac:` namespace attributes
- `stripAttributes` removing `style` from `img` tags
- Import detection using page ID manifest instead of filename-only matching

### Changed
- Reorganized repo into `python-web/` and `swift-app/` subdirectories
- Unified versioning across both projects

## [1.0.0] - 2026-02-13

### Added
- CLI tool (`confluence_to_flare.py`) for importing Confluence Cloud release notes into MadCap Flare
- Flask web UI (`web_app.py`) with Server-Sent Events for real-time progress streaming
- Date-ordered insertion into Release Notes Overview page and Mini-TOC (newest-first)
- Image downloading from Confluence attachments with original filenames
- Support for 6+ Confluence page title date naming conventions
- Jinja2 template for Flare HTM topic generation with Release Notes Image snippet
- Content converter for Confluence XHTML to Flare-compatible HTML
- Example configuration file (`config.yaml.example`)

[1.2.0]: https://github.com/stevesabatini/confluence-to-flare/releases/tag/v1.2.0
[1.1.0]: https://github.com/stevesabatini/confluence-to-flare/releases/tag/v1.1.0
[1.0.0]: https://github.com/stevesabatini/confluence-to-flare/releases/tag/v1.0.0
