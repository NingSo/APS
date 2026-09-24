#!/usr/bin/env python3
"""Fetch only the pinned upstream Gradle wrapper binary and verify its Git blob ID.

This does not install the Android SDK, invoke Gradle, or read authentication tokens.
The Gradle distribution and Maven dependencies are downloaded later by Gradle itself.
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import sys
import tempfile
from urllib.error import URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "gradle/wrapper/gradle-wrapper.jar"
BASELINE = "a785282cf172112590e992165090b4729d5f64dc"
EXPECTED_BLOB = "b1b8ef56b44f16b14dc800fa8103a6d89abb526f"
URL = f"https://raw.githubusercontent.com/hect0x7/android-proxy-server/{BASELINE}/gradle/wrapper/gradle-wrapper.jar"

def git_blob_id(data: bytes) -> str:
    return hashlib.sha1(f"blob {len(data)}\0".encode("ascii") + data).hexdigest()

def ensure_wrapper() -> None:
    if TARGET.exists():
        if git_blob_id(TARGET.read_bytes()) != EXPECTED_BLOB:
            raise RuntimeError("Existing wrapper does not match the pinned upstream binary; refusing to execute it.")
        return
    request = Request(URL, headers={"User-Agent": "APS-wrapper-bootstrap"})
    with urlopen(request, timeout=45) as response:
        data = response.read(131_073)
    if len(data) > 131_072 or git_blob_id(data) != EXPECTED_BLOB:
        raise RuntimeError("Downloaded wrapper does not match the pinned upstream Git blob.")
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=TARGET.parent, delete=False) as output:
            temporary = Path(output.name)
            output.write(data)
        os.replace(temporary, TARGET)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)
    print("Pinned Gradle wrapper verified and installed.")

if __name__ == "__main__":
    try:
        ensure_wrapper()
    except (OSError, URLError, RuntimeError) as error:
        print(f"Gradle wrapper bootstrap failed: {error}", file=sys.stderr)
        sys.exit(1)
