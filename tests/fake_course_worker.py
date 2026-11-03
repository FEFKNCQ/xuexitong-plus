"""Stand-in for `chaoxing-worker --list-courses` (no network). FAKE_COURSES_FAIL=1 -> login error."""
import json
import os
import sys

if "--list-courses" not in sys.argv:
    print("unexpected mode", sys.argv)
    sys.exit(2)
print("\x1b[32m2026-11-03 10:00:00.000\x1b[0m | INFO     | api.base:login:1 - 登录成功", flush=True)
if os.environ.get("FAKE_COURSES_FAIL") == "1":
    print("__CX_COURSES__" + json.dumps({"ok": False, "error": "登录失败：密码错误"}, ensure_ascii=False), flush=True)
    sys.exit(1)
courses = [
    {"courseId": "2151141", "clazzId": "9001", "title": "大学物理（上）", "teacher": "张老师", "desc": ""},
    {"courseId": "189191", "clazzId": "9002", "title": "马克思主义基本原理", "teacher": "李老师", "desc": ""},
    {"courseId": "198198", "clazzId": "9003", "title": "计算机网络", "teacher": "王老师", "desc": ""},
]
print("__CX_COURSES__" + json.dumps({"ok": True, "courses": courses}, ensure_ascii=False), flush=True)
