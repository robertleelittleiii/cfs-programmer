# Firmware Releases

This directory contains official, versioned firmware binaries for distribution.

## Why This Directory Exists

The `firmware/build/` and `firmware/build-*/` directories are now excluded from version control via `.gitignore`. This change was made because:

1. **Reproducibility** — Build artifacts can be regenerated from source code
2. **Repository size** — Compiled binaries are large and bloat git history
3. **Merge conflicts** — Binary files cause unnecessary conflicts between contributors
4. **Toolchain differences** — Different ESP32/Arduino toolchain versions produce different binaries

## How to Use This Directory

Place tagged, versioned release binaries here for users who need pre-built firmware without setting up the build toolchain.

**Naming convention:**
```
CFS_Handheld_v{VERSION}.bin
CFS_Handheld_v{VERSION}_OTA.bin
```

**Example:**
```
CFS_Handheld_v1.2.0.bin
CFS_Handheld_v1.2.0_OTA.bin
```

## Building Firmware Locally

To build firmware from source, see `firmware/README.md` for toolchain setup and build instructions.
