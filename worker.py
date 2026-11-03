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


COURSES_PREFIX = "__CX_COURSES__"


def list_courses(config_path: Path, data_dir: Path) -> int:
    """Log in with the saved account and print the course list as one JSON line.

    Used by the GUI's "识别课程" button; no question bank, no tasks.
    """
    import json

    def emit(payload: dict) -> None:
        print(COURSES_PREFIX + json.dumps(payload, ensure_ascii=False), flush=True)

    data_dir.mkdir(parents=True, exist_ok=True)
    os.chdir(data_dir)
    from main import load_config_from_file
    from api.base import Account, Chaoxing

    common, _tiku, _notify = load_config_from_file(str(config_path))
    use_cookies = bool(common.get("use_cookies", False))
    username, password = common.get("username", ""), common.get("password", "")
    if not use_cookies and (not username or not password or username.lower() == "xxx"):
        emit({"ok": False, "error": "还没有填写账号和密码"})
        return 3
    try:
        chaoxing = Chaoxing(account=Account(username, password))
        state = chaoxing.login(login_with_cookies=use_cookies)
        if not state.get("status"):
            emit({"ok": False, "error": f"登录失败：{state.get('msg') or '未知原因'}"})
            return 1
        courses = chaoxing.get_course_list()
    except Exception as exc:  # network / parsing problems are reported, not raised
        emit({"ok": False, "error": f"{type(exc).__name__}: {exc}"})
        return 1
    keys = ("courseId", "clazzId", "title", "teacher", "desc")
    emit({"ok": True, "courses": [{k: str(c.get(k, "") or "") for k in keys} for c in courses]})
    return 0


def run_worker(argv: list[str]) -> int:
    _utf8_streams()
    if len(argv) == 4 and argv[1] == "--list-courses":
        return list_courses(Path(argv[2]).resolve(), Path(argv[3]).resolve())
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
