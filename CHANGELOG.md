# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.8.0]

### Added
- `createld` support, as a third disk type choice under the "create a CHD
  from one file" menu option, for LaserDisc AVI sources
- `extractld` support, as a fifth output format choice for both
  single-file and batch extraction

## [0.7.0]

### Added
- `createraw` support, as a second choice under the existing "compress a
  hard disk image" menu option, prompting for `--hunksize`/`--unitsize`
  (defaulting to 2048 when left blank)
- `extractraw` support, as a fourth output format choice for both
  single-file and batch extraction (batch mode asks for `--unitsize` once
  for the whole batch)

## [0.6.0]

### Added
- Timestamped execution log on all three scripts: a `chdman-tool_<timestamp>.log`
  file is created next to the script on the first `chdman` command actually
  run (no file created for a session that never performs an operation),
  recording every `create`/`extract`/`verify`/`info`/`createhd` call with its
  timestamp, input/output paths and result (OK/FAILED)

## [0.5.0]

### Added
- Confirmation prompt before overwriting an existing output file, on all
  three scripts (Windows, Linux, macOS), replacing the previous silent
  `--force` behaviour: single-file operations (create, extract, `createhd`)
  now ask before overwriting; batch operations (create, extract) ask once
  with a count of how many existing files would be overwritten, rather than
  once per file
- CI workflow (`.github/workflows/validate-native-binaries.yml`) that runs
  `createhd`, `verify` and `info` with the embedded native binaries on real
  GitHub Actions runners for Linux (x64, arm64) and macOS (x64, arm64)

## [0.4.0]

### Added
- Native `chdman` 0.289.0 binaries embedded for Linux (x64, arm64) and macOS
  (x64, arm64), resolving the main blocker of the multi-platform port. No
  official precompiled `chdman` exists for these platforms from MAMEdev, so
  these binaries are unofficial redistributions published by a third party
  (the `chdman-js` project); their provenance, checksums and license are
  documented in `COMPILATION.md` (section 7) and `LICENSE`
- `chdman-tool.sh` (Linux and macOS): binary detection now also recognizes
  the per-architecture `bin/macos/<arch>/chdman` layout required because the
  macOS binary depends on a bundled `libSDL3.0.dylib`, loaded via
  `@executable_path`, which is architecture-specific and cannot be shared
  between x64 and arm64 packages

### Fixed
- `i18n/*.lang`: several menu strings (`BATCH_TYPE_CD`, `BATCH_TYPE_DVD`,
  `BATCH_CD_LABEL`, `BATCH_DVD_LABEL`, `BATCH_EXTRACT_LABEL`) contained a
  literal `->` arrow. In `CHDMAN_Tool.bat`, an unquoted `echo %VAR%` expands
  the variable before the line is parsed for redirection operators, so the
  `>` character was interpreted by `cmd.exe` as a redirection instead of
  being printed, truncating the menu display and creating stray files named
  `createcd` / `createdvd` in the current directory. Replaced with
  redirection-safe phrasing (`(createcd)` / `(createdvd)`, plain labels) in
  all six language files
- `i18n/ja.lang`: four prompts (`PROMPT_DROP_FILE_CUE`, `PROMPT_DROP_FILE_CHD`,
  `PROMPT_DROP_FILE_HD`, `PROMPT_DROP_FOLDER`) contained a literal `&`
  (half-width, from "drag & drop" written in Japanese). For the same
  unquoted-`echo` reason, `cmd.exe` would treat it as its command-separator
  operator, cutting the displayed text short and attempting to run the
  remainder as a command. Replaced with the full-width `＆` character,
  which is visually equivalent and common in Japanese typography

### Known limitations
- These native binaries have not been validated by real execution on Linux
  or macOS hardware yet (only inspected statically: file type, checksum,
  presence of required subcommands)
- The Linux binaries are built against musl libc rather than glibc

## [0.3.0]

### Added
- Linux and macOS support: a single portable `chdman-tool.sh` script
  (bash >= 3.2 compatible) providing the exact same menu, options and
  behaviour as the Windows script, fully driven by the same `.lang` files,
  shipped identically in `src/linux/` and `src/macos/`
- Automatic detection of the `chdman` binary matching the running OS and
  CPU architecture (x64 / arm64)
- `.gitattributes` to enforce consistent line endings across platforms
  (CRLF for `.bat`, LF for `.sh`, `.lang` and documentation files)

### Known limitations
- No native `chdman` binary is bundled yet for Linux or macOS: MAME does not
  publish official precompiled binaries for these platforms (Windows only).
  `chdman-tool.sh` has been tested with a stub binary that only exercises
  the menu, i18n and batch-processing logic, not real CHD compression
- `chdman-tool.sh` has not been tested on an actual macOS system; bash 3.2
  compatibility has only been verified by static review of the script

## [0.2.0]

### Added
- Full internationalization: language files for English (reference), French,
  German, Spanish, Japanese and Chinese (Simplified) in `i18n/*.lang`
- Language selector shown on first run, with automatic system-language
  detection and manual override; the chosen language is remembered locally
  between runs
- New menu option to change the active language at any time
- `chcp 65001` invoked at startup so multi-byte languages (Japanese, Chinese)
  render correctly in the console

### Changed
- `src/windows/CHDMAN_Tool.bat` no longer contains any hard-coded displayed
  string (apart from the very first startup check, which cannot yet depend
  on a loaded language file); every label, prompt and message is now sourced
  from the active `.lang` file
- Main menu renumbered to accommodate the new "change language" option (now
  9 entries instead of 8)

### Known limitations
- Visual validation of all 6 languages on native Windows, Linux and macOS
  terminals is still pending

## [0.1.0]

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

[Unreleased]: https://github.com/patrickjaillet/CHDMan-Batch/compare/v0.8.0...HEAD
[0.8.0]: https://github.com/patrickjaillet/CHDMan-Batch/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/patrickjaillet/CHDMan-Batch/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/patrickjaillet/CHDMan-Batch/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/patrickjaillet/CHDMan-Batch/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/patrickjaillet/CHDMan-Batch/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/patrickjaillet/CHDMan-Batch/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/patrickjaillet/CHDMan-Batch/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/patrickjaillet/CHDMan-Batch/releases/tag/v0.1.0
