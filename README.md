# CHDman Batch UI

A portable, menu-driven interface for `chdman` — create, extract, verify and inspect CHD (Compressed Hunks of Data) files without touching a command line.

No installer. No setup. Extract the archive, run the script for your platform, and you're done.

---

## Features

- **Create** CHD files from CD images (`.cue`, `.gdi`) or DVD images (`.iso`) — single file or entire folder trees
- **Extract** CHD files back to CUE+BIN, GDI, or ISO
- **Verify** the integrity of an existing CHD file
- **Inspect** detailed metadata of a CHD file
- **Compress** raw hard disk images into CHD format
- Batch mode: recursively scans a folder and processes every matching file
- Available in English, French, German, Spanish, Japanese, and Chinese

## Supported platforms

| Platform | Status |
|---|---|
| Windows (x64) | Available |
| Linux (x64, arm64) | Available (script and native `chdman` binary embedded; not yet validated on real hardware) |
| macOS (x64, arm64) | Available (script and native `chdman` binary embedded; not yet validated on real hardware) |

## Getting started

1. Download the latest release for your platform from the [Releases](../../releases) page
2. Extract the archive anywhere on your system — no installation required
3. Run the script for your platform:
   - **Windows:** double-click `CHDMAN_Tool.bat`
   - **Linux / macOS:** run `./chdman-tool.sh` from a terminal
4. Follow the on-screen menu

The tool ships with its own copy of `chdman`, so nothing else needs to be installed.

## Supported input formats

| Source format | Console examples | Target |
|---|---|---|
| `.cue` / `.bin` | PlayStation, Saturn, Sega CD | CD CHD |
| `.gdi` | Dreamcast | CD CHD |
| `.iso` | GameCube, PlayStation 2, Xbox, PSP | DVD CHD |
| Raw disk image | Arcade hard disk dumps | HD CHD |

## Project layout

```
CHDman-Batch-UI/
├── bin/            Embedded chdman binaries, per platform
├── src/            Menu scripts, per platform
├── i18n/           Language files
├── docs/           User documentation
├── tests/          Manual and automated test scenarios
├── LICENSE
├── README.md
├── CHANGELOG.md
└── VERSION
```

## License

This project's own code (scripts, language files, documentation, build tooling) is released under the [MIT License](LICENSE).

The embedded `chdman` binary is part of the [MAME project](https://github.com/mamedev/mame) and is distributed unmodified under its own license (GPL-2.0-or-later, with most individual MAME source files under the 3-Clause BSD License). See the `LICENSE` file for the full third-party notice. MAME is a registered trademark of Gregory Ember; this project is not affiliated with or endorsed by the MAME development team.

## Contact

- **Author:** Patrick JAILLET
- **E-mail:** sandefjord.development@proton.me
- **Website:** https://patrickjaillet.github.io/CHDMan-Batch-UI

## Contributing

Issues and pull requests are welcome. Please check the open issues before submitting a new one.
