# Changelog

All notable changes to the CFS Programmer firmware and Mac app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Mac app: seven printer-sourced Generic profiles: PET-CF (`00013`), PLA-HT-GF (`00040`), ABS-GF (`00041`), ABS-CF (`00042`), PET-GF15 (`00043`), PC-CF (`00044`), and ABS-FR (`00045`).
- Standalone Swift catalog regression checks in `mac-app/tests/K2MaterialCatalogTests.swift`.
- [Production Mac app update instructions](docs/MAC_APP_UPDATES.md), including database backup, signing, import verification, and rollback.

### Changed
- Mac app stock catalog expanded from 40 profiles / 14 types to 47 profiles / 20 types, verified against a live K2 material database on 2026-10-18.
- New profiles preserve printer IDs, names, densities, diameter, primary colors, and nozzle-temperature ranges. Unspecified ranges remain zero; default temperatures use the existing midpoint convention.
- Preserved the printer's `PETG-GF` classification for Generic PET-GF15. Existing startup seeding imports the additions; no printer or programmer firmware update is required for this catalog change.

### Fixed
- Corrected Mac app custom-material RFID fallback IDs using the K2 Generic catalog; unknown types no longer silently encode PLA.
- Corrected firmware material labels: `101002`/`101003`/`101004` are PLA variants, not PETG/ABS/TPU. The new firmware identifies itself as 1.3.10.
- Prevented cloned custom profiles from retaining a known PLA base ID after changing their type, and rejected malformed tag fields before issuing write commands.
- Bounded the firmware's post-write plaintext logging to the verified 48 bytes instead of reading past an unterminated buffer.
- Moved OLED status text below the top row while keeping all three baselines inside the 64-pixel display.

The 1.3.7–1.3.9 entries below are historical notes retained from earlier local work; their boot-recovery behavior was not independently revalidated during the 1.3.10 material-ID update.

## [1.3.9] - 2026-08-18

### Fixed
- Frozen boot splash: if the PN532 held I2C low, OLED `begin()` never returned. Firmware now recovers open-drain, skips the display when the bus is still stuck, and still starts BLE.

## [1.3.8] - 2026-08-18

### Fixed
- Boot splash could stick forever: a failed PN532 probe scanned the whole I2C bus and tripped the ESP32 watchdog, rebooting with the OLED still showing “Booting…”
- Boot no longer runs the multi-second LED self-test; BLE comes up before NFC

## [1.3.7] - 2026-08-18

### Fixed
- RFID read/write could hang the ESP32 and drop the Mac BLE link: the PN532 default is “search for a card forever,” and a later I2C command then clock-stretches until a tag appears
- Tag polling now uses a finite PN532 retry count, a bounded I2C timeout, and no longer re-sends SAMConfig every 2 seconds while waiting

## [1.3.0] - 2026-07-10

### Added
- ESP32 and ESP32-S3 board profiles with safe pin maps per MCU
- TAG_DATA film ID (`ID:`) and vendor code (`VENDOR:`) for Mac material/brand lookup
- Dual-tag write verification improvements
- `firmware/flash.sh` helper for serial flashing

### Changed
- Versioning aligned: code + docs report **1.3.0** (sketch folder name `CFS_Handheld_v1.2_OTA` is historical only)
- OTA GitHub API URL set to `MakaiView/cfs-programmer`

### Fixed
- Classic ESP32 must not use S3 pin map (GPIO 8/9); that conflicts with SPI flash and can prevent boot
- Coarse “PLA only” read display; Mac app maps film/vendor IDs to catalog names

## [1.2.0] - 2025-12-21

### Added
- OTA firmware update support via WiFi
- Firmware versioning system with automatic version reporting over BLE
- WiFi configuration over BLE (WIFI_CONFIG command)
- GitHub releases integration for automatic update checking
- CHECK_UPDATE command to query GitHub API for new versions
- OTA_UPDATE command to download and install firmware from URL
- Blank tag detection (all zeros in data blocks)
- Magenta LED color for OTA update in progress
- Build date/time tracking in firmware

### Changed
- Improved BLE protocol with version handshake on connect
- Enhanced error messages for better debugging
- Updated serial output formatting for better readability

### Fixed
- None in this release

## [1.1.0] - 2025-12-20

### Added
- Authentication retry logic with up to 3 attempts per operation
- Tag re-selection between retry attempts for better reliability
- Blank tag detection and reporting
- Improved serial output with formatted boxes and emojis

### Changed
- Authentication now tries multiple key combinations automatically
- Better error handling for authentication failures

### Fixed
- Timing issues with PN532 authentication (requires library patch)
- Intermittent authentication failures on valid tags

## [1.0.0] - 2025-12-19

### Added
- Initial release
- Read Creality CFS tags via PN532 NFC reader
- Decrypt tag data using AES-128
- UID-based MIFARE key generation
- BLE interface for Mac app communication
- OLED display support (SH1106 128x64)
- WS2812B RGB LED status indicators
- Support for MIFARE Classic 1K tags

### Supported Commands
- READ - Read and decode CFS tag
- CANCEL - Cancel current operation
- GET_VERSION - Request firmware version

---

## Version Number Guidelines

- **MAJOR** version: Breaking changes to BLE protocol or hardware requirements
- **MINOR** version: New features, backward compatible
- **PATCH** version: Bug fixes only

## Release Process

1. Update version in firmware code: `#define FIRMWARE_VERSION "X.Y.Z"`
2. Update this CHANGELOG.md with changes
3. Commit changes: `git commit -m "Release vX.Y.Z"`
4. Create tag: `git tag -a fw-vX.Y.Z -m "Version X.Y.Z"`
5. Push: `git push origin main --tags`
6. GitHub Actions automatically builds and creates release
