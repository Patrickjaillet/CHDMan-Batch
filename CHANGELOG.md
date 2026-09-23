# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial repository structure (`bin/`, `src/`, `i18n/`, `docs/`, `tests/`)
- Windows menu script (`src/windows/CHDMAN_Tool.bat`) with 8 operations:
  create CHD (single file), create CHD (batch), extract CHD (single file),
  extract CHD (batch), verify CHD integrity, display CHD info, compress hard
  disk image, quit
- Embedded `chdman` binary for Windows x64, version 0.289 (from MAME 0.289)
- `LICENSE` (MIT for project code, third-party notice for the embedded
  GPL-2.0-or-later `chdman` binary)
- `README.md`, `CHANGELOG.md`, `VERSION`, `.gitignore`

### Known limitations
- Windows only; Linux and macOS scripts not yet implemented
- French language only; English, German, Spanish, Japanese and Chinese
  translations not yet implemented
- No automated tests yet
- Destructive operations (`--force`) run without user confirmation

[Unreleased]: https://github.com/patrickjaillet/CHDMan-Batch-UI/compare/v0.1.0...HEAD
