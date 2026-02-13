# Changelog

All notable changes to the Confluence-to-Flare Import Tool will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/stevesabatini/confluence-to-flare/releases/tag/v1.0.0
