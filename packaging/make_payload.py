# -*- coding: utf-8 -*-
"""Build the installer payload: the release folder as an LZMA zip.

The setup program reads the payload with ``zipfile``, which handles LZMA, and LZMA makes
the download about a quarter smaller than Deflate (98 -> 72 MB for 1.1.9). The separate
no-install zip stays Deflate because Windows Explorer cannot open LZMA zips.

Usage: python make_payload.py <dist>\\学习通PLUS <out.zip>
"""

from __future__ import annotations

import os
import sys
import zipfile


def build(release_dir: str, out: str) -> None:
    base = os.path.dirname(os.path.abspath(release_dir))
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_LZMA) as archive:
        for dirpath, _dirs, files in os.walk(release_dir):
            for name in sorted(files):
                full = os.path.join(dirpath, name)
                # Entries start with the folder name ("学习通PLUS/..."), like the release zip.
                archive.write(full, os.path.relpath(full, base).replace("\\", "/"))


if __name__ == "__main__":
    build(sys.argv[1], sys.argv[2])
    print(f"payload: {os.path.getsize(sys.argv[2]) / 1024 / 1024:.0f} MB (LZMA)")
