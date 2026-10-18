#!/usr/bin/env python3
"""Run catalog, outgoing-payload, and cross-language firmware-ID checks on macOS."""

from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "mac-app/CFS Programmer"


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


with tempfile.TemporaryDirectory(prefix="cfs-tag-tests-") as directory:
    output = Path(directory)
    run("swiftc", str(APP / "Models/K2MaterialCatalog.swift"),
        str(ROOT / "mac-app/tests/K2MaterialCatalogTests.swift"),
        "-o", str(output / "catalog-tests"))
    run(str(output / "catalog-tests"))
    run("swiftc", *map(str, sorted((APP / "Models").glob("*.swift"))),
        str(ROOT / "mac-app/tests/TagWritingTests.swift"),
        "-o", str(output / "tag-tests"))
    run(str(output / "tag-tests"))
    payloads = run(str(output / "tag-tests"), "--emit-payloads", capture_output=True).stdout
    run("clang++", "-std=c++11", "-Wall", "-Wextra", "-Werror",
        str(ROOT / "firmware/tests/material_ids_test.cpp"),
        "-o", str(output / "firmware-tests"))
    run(str(output / "firmware-tests"), input=payloads)

    # Keep the firmware mirror in sync with the authoritative app catalog.
    catalog = (APP / "Models/K2MaterialCatalog.swift").read_text()
    expected = dict(re.findall(
        r'StockMaterial\(id: "([^"]+)".*?materialType: "([^"]+)"', catalog
    ))
    header = (ROOT / "firmware/CFS_Handheld_v1.2_OTA/CFSMaterialIDs.h").read_text()
    mirrored = re.findall(r'\{"([^"]+)", "([^"]+)"\}', header)
    assert len(mirrored) == len(dict(mirrored)) == len(expected) == 47
    assert dict(mirrored) == expected
    print("App/firmware catalog mirrors match exactly.")
