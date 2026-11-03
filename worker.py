# -*- coding: utf-8 -*-
"""Console entry point used by the GUI subprocess."""

from __future__ import annotations

import os
import sys
from pathlib import Path


def run_worker(argv: list[str]) -> int:
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
