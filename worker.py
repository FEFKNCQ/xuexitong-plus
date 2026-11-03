# -*- coding: utf-8 -*-
"""Console entry point used by the GUI subprocess."""

from __future__ import annotations

import os
import sys
from pathlib import Path


def _utf8_streams() -> None:
    """The GUI reads our output as UTF-8. The packaged exe ignores PYTHONUTF8 and would
    otherwise write in the system code page (GBK on Chinese Windows) -> garbled log."""
    for stream in (sys.stdout, sys.stderr):
        if stream is not None and hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


def run_worker(argv: list[str]) -> int:
    _utf8_streams()
    if len(argv) != 4 or argv[1] != "--worker":
        print("用法: chaoxing-worker.exe --worker <config.ini> <data-directory>")
        return 2

    config_path = Path(argv[2]).resolve()
    data_dir = Path(argv[3]).resolve()
    data_dir.mkdir(parents=True, exist_ok=True)
    os.chdir(data_dir)
    sys.argv = ["main.py", "-c", str(config_path)]

    import main

    main.main()
    return 0


if __name__ == "__main__":
    raise SystemExit(run_worker(sys.argv))
