# Mac app catalog update and production installation

## Catalog changes

On 2026-10-18, seven missing profiles were read from the K2 printer's `/mnt/UDISK/creality/userdata/box/material_database.json` and added to `mac-app/CFS Programmer/Models/K2MaterialCatalog.swift`:

- `00013` — Generic PET-CF; type `PET-CF`; density 1.24 g/cm³; nozzle range 280–320°C.
- `00040` — Generic PLA-HT-GF; type `PLA-GF`; density 1.33 g/cm³; nozzle range unspecified.
- `00041` — Generic ABS-GF; type `ABS-GF`; density 1.08 g/cm³; nozzle range 240–270°C.
- `00042` — Generic ABS-CF; type `ABS-CF`; density 1.06 g/cm³; nozzle range 240–270°C.
- `00043` — Generic PET-GF15; type `PETG-GF`; density 1.43 g/cm³; nozzle range unspecified.
- `00044` — Generic PC-CF; type `PC-CF`; density 1.16 g/cm³; nozzle range unspecified.
- `00045` — Generic ABS-FR; type `ABS-FR`; density 1.05 g/cm³; nozzle range unspecified.

All use 1.75 mm diameter. PET-CF's primary color is white; the other six are black. The printer classifies PET-GF15 as `PETG-GF`; the app deliberately preserves that value.

The stock catalog now has **47 profiles across 20 types**: 25 Creality and 22 Generic. Unspecified nozzle ranges are stored as zero, not invented recommendations. The app derives the new profiles' default nozzle temperatures from the midpoint of their specified ranges, or zero when unspecified. Consult the spool manufacturer's recommendations before printing.

This is a source-catalog update, not a new continuous network-sync feature. `DatabaseManager.seedK2CatalogIfNeeded()` imports the additions during app initialization, keyed by printer material ID. It adds missing stock profiles and retains custom profiles, notes, favorites, spool history, and settings. Existing stock identity/physical defaults can be normalized by the existing seeding logic. The seven profiles also become available to the material-type pickers and film-ID lookup through the existing catalog mechanisms.

No printer database writes, printer firmware updates, or ESP32 programmer firmware updates are needed for this catalog-only change. The `fw-v*` GitHub workflow builds programmer firmware, not the Mac app.

## Verification already completed

- Standalone Swift regression checks passed: 47 unique material IDs, 20 types, expected brand counts, and the seven new profiles' catalog values.
- A full Debug Xcode build succeeded with code signing disabled.
- The built app was launched and its main window activated/reopened. Startup seeding persisted all 47 profiles.
- All 47 saved stock records were checked against the source catalog for IDs, base IDs, names, types, brands, stock flags, densities, diameters, nozzle min/max/default values, primary colors, and 250/500/750/1000 g weight options.
- `git diff --check` passed.

This does **not** verify a signed Release upgrade of the existing sandboxed production database. The test app was built at `/tmp/cfs-programmer-catalog-build/Build/Products/Debug/CFS Programmer.app`; it was not installed over an existing app.

## Data locations: do not overwrite production with the test database

The unsigned Debug app used:

`~/Library/Application Support/CFS-Programmer/materials.json`

The existing sandboxed database is:

`~/Library/Containers/MakaiView.CFS-Programmer/Data/Library/Application Support/CFS-Programmer/materials.json`

During verification, the test database had 47 profiles and the sandboxed database still had 41 entries. The latter was not modified. An upgraded production database may have **more than 47 entries** because custom profiles must remain.

Do not copy the test database over the production database: doing so could discard production-only custom materials, notes, spool records, and settings.

## Update the production app

### 1. Locate the installed copy and back up

Quit every CFS Programmer instance, including the temporary Debug build. Locate the actual installed application in Finder; no copy was found directly in `/Applications` or `~/Applications` during this session. Keep an unchanged copy of the old `.app` in your backup folder.

Back up both possible data directories while the app is closed. Run this in Terminal:

```bash
BACKUP_DIR="$HOME/CFS-Programmer-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
SANDBOX_DATA="$HOME/Library/Containers/MakaiView.CFS-Programmer/Data/Library/Application Support/CFS-Programmer"
LOCAL_DATA="$HOME/Library/Application Support/CFS-Programmer"
if [ -d "$SANDBOX_DATA" ]; then
  ditto "$SANDBOX_DATA" "$BACKUP_DIR/sandboxed-data"
fi
if [ -d "$LOCAL_DATA" ]; then
  ditto "$LOCAL_DATA" "$BACKUP_DIR/local-data"
fi
```

Check the backup folder contains the expected `materials.json` before proceeding. Do not rely only on the app's rotating `materials.backup.json`.

### 2. Build a signed Release application

Use the source checkout containing the catalog changes and Xcode with the macOS SDK required by the project. The current deployment target is **macOS 26.1**; do not assume this build supports older systems.

From the repository root:

```bash
open "mac-app/CFS Programmer/CFS Programmer.xcodeproj"
```

In Xcode:

1. Select the **CFS Programmer** target and configure **Signing & Capabilities** using the same team/signing setup as the installed app. The checked-in project currently has no development team set.
2. Keep bundle identifier **`MakaiView.CFS-Programmer`**, **App Sandbox**, and the existing Bluetooth/network capabilities. Changing signing identity/team or sandbox behavior can change access to the existing container.
3. Assign the intended Mac app version and a new build number using your normal release convention. The Xcode bundle settings currently say version `1.0`, build `1`; the UI/README's `1.3.0` label and programmer firmware version are separate and are not proof that this catalog update is installed.
4. Select the **CFS Programmer** scheme and a Mac destination. Use **Product → Archive**, then export using the signing/distribution method appropriate for the existing deployment. For distribution to other Macs outside the App Store, use the normal Developer ID and notarization process; the unsigned Debug build is not a production distribution artifact.

For a local signed Release build after configuring signing in Xcode, this is an alternative to archiving:

```bash
xcodebuild \
  -project "mac-app/CFS Programmer/CFS Programmer.xcodeproj" \
  -scheme "CFS Programmer" \
  -configuration Release \
  -derivedDataPath "$HOME/Library/Developer/Xcode/DerivedData/CFS-Programmer-Production" \
  CODE_SIGNING_ALLOWED=YES \
  build
```

Its app is at `~/Library/Developer/Xcode/DerivedData/CFS-Programmer-Production/Build/Products/Release/CFS Programmer.app`. Do not work around a signing failure by disabling signing for the production update.

### 3. Replace only the application bundle

With the old app still closed, use Finder to replace the application at its actual installed location with the signed Release/exported `.app`. Leave both Application Support directories and the sandbox container in place.

Launch that exact installed copy, not the temporary `/tmp` build. Open its main window if macOS restores it without a window; in the Debug verification, activating/reopening the window was required before database initialization occurred.

### 4. Verify the production import

In **Materials**, confirm that all seven names listed above are present. Existing custom profiles, notes, favorites, and spool data should still be present.

For a normal sandboxed installation, verify the persisted IDs without dumping settings or credentials:

```bash
python3 - <<'PY'
import json
from pathlib import Path

path = (Path.home() / "Library/Containers/MakaiView.CFS-Programmer/Data"
        / "Library/Application Support/CFS-Programmer/materials.json")
data = json.loads(path.read_text())
expected = {
    "00013": "Generic PET-CF",
    "00040": "Generic PLA-HT-GF",
    "00041": "Generic ABS-GF",
    "00042": "Generic ABS-CF",
    "00043": "Generic PET-GF15",
    "00044": "Generic PC-CF",
    "00045": "Generic ABS-FR",
}
for material_id, name in expected.items():
    matches = [m for m in data["materials"] if m["id"] == material_id]
    assert len(matches) == 1, f"Missing or duplicate ID: {material_id}"
    material = matches[0]
    assert material["name"] == name, f"Wrong name: {material_id}"
    assert material["brandName"] == "Generic"
    assert material["isCustom"] is False
    print(f"Verified: {material_id} {name}")
print(f"All seven imported. Total entries: {len(data['materials'])}")
PY
```

If the existing production deployment intentionally uses the non-sandboxed path, use that path instead. Verify the database used by the installed process, not whichever file already contains the expected entries.

Compare the upgraded data with the timestamped backup to confirm production-only custom records and history survived. The signed production upgrade is not complete until these checks pass. No new printer SSH connection or credentials are needed for startup seeding.

### 5. Roll back if necessary

Quit the new app. Preserve a separate copy of its current data if you have made changes since the update. Replace its `.app` with the backed-up previous version. If the database also needs reverting, restore the matching pre-update data directory from the timestamped backup to its original location while the app is closed, then relaunch.

Restoring an older database loses changes made after that backup; do not mix the unsigned test database and sandboxed production data.

## Re-run catalog regression checks

### RFID material-ID correction

The follow-up writing fix replaces the old type-to-ID fallback table with real Generic catalog IDs. PETG now falls back to `100003`, ABS to `100004`, TPU to `100005`, PA/Nylon to `100008`, and ASA to `100007`. Stock profile IDs remain unchanged. In particular, `101002` is Hyper L-W PLA, not PETG.

Firmware 1.3.10 uses the same catalog for read-back labels. Deploy the updated app for corrected payload generation and update the programmer firmware for corrected device-side labels. This is separate from the earlier catalog-only change, which did not require a firmware update. Existing physical tags are not modified by an app/firmware update.

Run the combined host regression suite from the repository root:

```bash
python3 mac-app/tests/run_tag_tests.py
```

It compiles the Swift encoder and the actual firmware material-ID lookup, checks all 47 outgoing payloads against the firmware decoder, checks the app/firmware catalog mirrors, and exercises fallback IDs, cloned-type changes, and invalid-input rejection. It does not drive the PN532, test RF positioning or authentication, or prove K2 acceptance.

#### Deployment verification on 2026-10-18

- Identified the connected programmer as ESP32-D0WD-V3 with 4 MB flash. Its existing partition table is `huge_app` (one 3 MB application slot), not an OTA two-slot layout.
- Compiled firmware 1.3.10 using `esp32:esp32:esp32:PartitionScheme=huge_app,FlashMode=dio,FlashFreq=40` and the repository's libraries. Program storage: 1,923,836 / 3,145,728 bytes; global RAM: 68,412 bytes.
- Compared the device partition table with the compiled table and confirmed an exact match. Flashed only the application at `0x10000` using 115200 baud; esptool verified the written image hash. Bootloader, partition table, and settings were not flashed.
- Confirmed the running programmer reports `VERSION:1.3.10`, initializes the PN532, starts BLE, and reaches `READY`.
- Attempts to read a complete rollback image failed with serial corruption; the partial dumps are not valid backups. Do not rely on them for recovery.
- The K2 was actively printing, so no RFID rescan or filament movement was requested. Read-only inspection found slot B configured as Generic PETG (`filamentId: 000003`, `materialType: PETG`), but its stored raw RFID payload was `unknown`. No scan matching the rewritten pair's serial `280201` was found in the recent log windows checked. This confirms PETG slot configuration, **not** acceptance of the rewritten tags. Complete the physical rescan below when the printer is idle.
- The host regression suite and full app source typecheck passed during development. A subsequent full app bundle build was cancelled; no updated production Mac app was installed.

#### Fresh K2 RFID acceptance verified

On 2026-10-18 at 03:02 UTC, the previous PETG print was reported completed, the printer was in `standby` / `Ready`, the SD job was inactive, the nozzle target was zero, and CFS unit T1 reported no filament loaded/detected in the toolhead path.

After checking the installed `BOX_INFO_REFRESH` macro and CFS slot addressing, issued one targeted `BOX_INFO_REFRESH ADDR=1 NUM=1` through Moonraker for T1B. The macro performs the CFS pre-loading/read sequence, fetches RFID data and remaining length, and returned `{"result": "ok"}`. No print, heating, homing, or toolhead unload command was issued.

The post-scan K2 `box.T1` status reported:

- Film ID: `100003` — Generic PETG, matching the printer catalog.
- Spool serial: `280201` — matches the programmer's latest two-tag write.
- Color: `066686D` — RGB `#66686D`.
- Remaining filament: `100`.
- Decoded RFID record: `ABA17000001100003066686D0330280201000000`.

This verifies that the K2 recognizes the rewritten PETG spool after a fresh reader refresh, superseding the earlier `unknown`/manual-slot-only evidence. It does not independently prove that each of the two physical tags was read separately; both tag writes were acknowledged by the programmer.

For physical verification after deployment:

1. Read each of the two rewritten tags independently. For Generic PETG, both must report `ID:100003`, the same spool serial/color, and a PETG material label with firmware 1.3.10. Old firmware can report a raw ID for this profile; the ID is authoritative.
2. If rewriting again, use the app's two-tag flow. Both `TAG1_WRITTEN` and `TAG2_WRITTEN` are required; each acknowledgement follows ciphertext read-back and full plaintext comparison. Keep the same pair's payload identical.
3. Place the pair on the spool and perform an RFID rescan using the printer's normal controls while idle. Confirm the K2 itself identifies PETG and the intended color. Do not start a print relying only on the programmer's label.
4. If `100003` still appears as PLA, collect the printer's scan result and both tag read-backs. Investigate authentication, tag compatibility/placement, and cached slot data separately instead of changing the material ID at random.

### Standalone catalog checks

From the repository root, compile and run the standalone checks; no printer connection is needed:

```bash
TEST_DIR=$(mktemp -d /tmp/cfs-catalog-tests.XXXXXX)
swiftc \
  "mac-app/CFS Programmer/Models/K2MaterialCatalog.swift" \
  "mac-app/tests/K2MaterialCatalogTests.swift" \
  -o "$TEST_DIR/catalog-tests" &&
  "$TEST_DIR/catalog-tests"
```

There is no Xcode test target for these checks; they are a standalone Swift executable.
