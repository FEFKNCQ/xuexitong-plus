# -*- coding: utf-8 -*-
"""Local AI tutor: explain questions with a local GGUF model served by llama.cpp.

Scope and boundaries
--------------------
* Everything here is for the user to *read*: the model explains a question and offers
  a reference answer, shown in the "AI 讲解" page. Nothing is written back to the task
  worker, config.ini's [tiku] section, or any answering / submission path.
* Results start as "待审核" (pending). The user reviews each one; only answers marked
  "采纳" can be copied. Reviews are kept in a local history file.
* No model downloading: the user points at GGUF / mmproj files they already have.

llama.cpp's ``llama-server`` exposes an OpenAI-compatible API; we use /health,
/v1/models and /v1/chat/completions (streamed as server-sent events).
"""

from __future__ import annotations

import base64
import json
import mimetypes
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
from dataclasses import asdict, dataclass, field, fields
from pathlib import Path
from typing import Iterable, Iterator

if os.name == "nt":
    DATA_DIR = Path(os.environ.get("APPDATA", Path.home())) / "ChaoxingDesktop"
else:
    DATA_DIR = Path.home() / ".config" / "chaoxing-desktop"
SETTINGS_FILE = "local_ai.json"
HISTORY_FILE = "ai_history.json"
HISTORY_LIMIT = 200
CREATE_NO_WINDOW = 0x08000000 if os.name == "nt" else 0

OPTION_RE = re.compile(r"^\s*([A-Ha-h])\s*[.、．:：)）]\s*(.+)$")
VERSION_RE = re.compile(r"version[:\s]+([0-9]+)(?:\s*\(([0-9a-f]+)\))?", re.IGNORECASE)
# "## 参考答案", "**参考答案：**", "参考答案:" ... (the colon may sit inside or outside the bold markers)
ANSWER_HEADING_RE = re.compile(r"^\s*(?:#+\s*)?(?:\*\*)?\s*参考答案\s*[:：]?\s*(?:\*\*)?\s*[:：]?\s*", re.MULTILINE)

SYSTEM_PROMPT = (
    "你是一位耐心的学习辅导老师。用户会给你一道练习题，请帮助他理解这道题：\n"
    "1. 先用“## 解析”作为标题，说明题目考查的知识点和解题思路，逐步推理；\n"
    "2. 再用“## 参考答案”作为标题，给出你认为正确的答案，并用一两句话说明理由；\n"
    "3. 如果题目信息不全或你没有把握，请明确说明不确定的地方，不要编造。\n"
    "回答使用简体中文。你的答案只是学习参考，需要用户自己核对。"
)


# ---------------------------------------------------------------- settings
@dataclass
class AiSettings:
    server_path: str = ""          # llama-server(.exe); empty = auto-detect
    external_url: str = ""         # use an already running server instead of starting one
    model_path: str = ""           # .gguf
    mmproj_path: str = ""          # multimodal projector .gguf (optional, for image questions)
    host: str = "127.0.0.1"
    port: int = 8089
    ctx_size: int = 4096
    gpu_layers: int = 0
    threads: int = 0               # 0 = llama.cpp default
    temperature: float = 0.3
    max_tokens: int = 1024
    extra_args: str = ""           # passed through to llama-server, space separated

    @classmethod
    def load(cls, folder: Path | None = None) -> "AiSettings":
        path = (folder or DATA_DIR) / SETTINGS_FILE
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return cls()
        known = {f.name: f for f in fields(cls)}
        values = {}
        for key, value in raw.items():
            if key not in known:
                continue
            kind = type(getattr(cls(), key))
            try:
                values[key] = kind(value)
            except (TypeError, ValueError):
                pass
        return cls(**values)

    def save(self, folder: Path | None = None) -> None:
        folder = folder or DATA_DIR
        folder.mkdir(parents=True, exist_ok=True)
        (folder / SETTINGS_FILE).write_text(json.dumps(asdict(self), ensure_ascii=False, indent=2), encoding="utf-8")

    @property
    def base_url(self) -> str:
        if self.external_url.strip():
            return self.external_url.strip().rstrip("/")
        return f"http://{self.host}:{self.port}"


def validate(settings: AiSettings, *, managed: bool) -> list[str]:
    """Problems that prevent starting a managed server (or using an external one)."""
    problems: list[str] = []
    if not managed:
        if not re.match(r"^https?://", settings.external_url.strip()):
            problems.append("外部服务地址需要以 http:// 或 https:// 开头")
        return problems
    model = Path(settings.model_path) if settings.model_path else None
    if model is None:
        problems.append("还没有选择 GGUF 模型文件")
    elif not model.is_file():
        problems.append("找不到模型文件")
    elif model.suffix.lower() != ".gguf":
        problems.append("模型文件需要是 .gguf 格式")
    if settings.mmproj_path:
        mmproj = Path(settings.mmproj_path)
        if not mmproj.is_file():
            problems.append("找不到 mmproj 文件")
        elif mmproj.suffix.lower() != ".gguf":
            problems.append("mmproj 文件需要是 .gguf 格式")
    if not 1 <= settings.port <= 65535:
        problems.append("端口需要在 1–65535 之间")
    if settings.ctx_size < 256:
        problems.append("上下文长度至少 256")
    return problems


# ---------------------------------------------------------------- detection
def candidate_server_paths(configured: str = "") -> list[Path]:
    names = ["llama-server.exe", "llama-server"] if os.name == "nt" else ["llama-server"]
    found: list[Path] = []

    def add(p: Path) -> None:
        if p not in found:
            found.append(p)

    if configured:
        add(Path(configured))
    for name in names:
        which = shutil.which(name)
        if which:
            add(Path(which))
    roots = []
    if os.name == "nt":
        for env in ("LOCALAPPDATA", "ProgramFiles", "USERPROFILE"):
            base = os.environ.get(env)
            if base:
                roots += [Path(base) / "llama.cpp", Path(base) / "Programs" / "llama.cpp"]
        roots += [Path("C:/llama.cpp"), Path("D:/llama.cpp")]
    else:
        roots += [Path.home() / "llama.cpp", Path("/usr/local/bin"), Path("/opt/llama.cpp")]
    for root in roots:
        for name in names:
            add(root / name)
            add(root / "build" / "bin" / name)
            add(root / "build" / "bin" / "Release" / name)
    return found


def probe_version(exe: Path, timeout: float = 10.0) -> str | None:
    """Run ``<exe> --version``; return e.g. 'b4321 (abc1234)' or None if it does not run."""
    try:
        proc = subprocess.run([str(exe), "--version"], capture_output=True, timeout=timeout,
                              creationflags=CREATE_NO_WINDOW)
    except (OSError, subprocess.SubprocessError):
        return None
    text = (proc.stdout + proc.stderr).decode("utf-8", errors="replace")
    match = VERSION_RE.search(text)
    if match:
        return f"b{match.group(1)}" + (f" ({match.group(2)})" if match.group(2) else "")
    return "未知版本" if proc.returncode == 0 else None


def detect_server(configured: str = "") -> tuple[Path | None, str | None]:
    """First llama-server that exists and runs, with its version."""
    for path in candidate_server_paths(configured):
        if path.is_file():
            version = probe_version(path)
            if version:
                return path, version
    return None, None


def build_server_args(settings: AiSettings) -> list[str]:
    args = ["-m", settings.model_path, "--host", settings.host, "--port", str(settings.port),
            "-c", str(settings.ctx_size), "-ngl", str(settings.gpu_layers)]
    if settings.mmproj_path:
        args += ["--mmproj", settings.mmproj_path]
    if settings.threads > 0:
        args += ["-t", str(settings.threads)]
    if settings.extra_args.strip():
        args += settings.extra_args.split()
    return args


# ---------------------------------------------------------------- questions
TYPE_LABELS = {"single": "单选题", "multiple": "多选题", "judgement": "判断题", "completion": "填空题"}


def question_from_work(item: dict) -> dict:
    """A question card from the chapter-quiz preview -> plain {type, title, options}."""
    options = [o.get("text", "") for o in item.get("options") or [] if isinstance(o, dict)]
    return {"type": item.get("typeLabel") or "题目", "title": str(item.get("title") or "").strip(), "options": options}


def parse_pasted(text: str) -> dict:
    """Split pasted text into stem and lettered options (A. / A、 / A) ...)."""
    stem: list[str] = []
    options: list[str] = []
    for line in (text or "").splitlines():
        if not line.strip():
            continue
        match = OPTION_RE.match(line)
        if match:
            options.append(f"{match.group(1).upper()}. {match.group(2).strip()}")
        elif options:
            options[-1] += " " + line.strip()   # wrapped option text
        else:
            stem.append(line.strip())
    kind = "选择题" if options else "题目"
    if not options and re.search(r"(对|错|正确|错误|√|×)\s*[)）]?\s*$", " ".join(stem)):
        kind = "判断题"
    return {"type": kind, "title": "\n".join(stem), "options": options}


def format_question(q: dict) -> str:
    lines = []
    # Course / chapter context (picked up from the run dashboard) helps the model pick the right field.
    if q.get("course"):
        lines.append(f"课程：{q['course']}")
    if q.get("chapter"):
        lines.append(f"章节：{q['chapter']}")
    lines += [f"题型：{q.get('type') or '题目'}", f"题目：{q.get('title') or '（见图片）'}"]
    if q.get("options"):
        lines.append("选项：")
        lines += [f"  {opt}" for opt in q["options"]]
    return "\n".join(lines)


def image_data_url(path: str) -> str:
    mime = mimetypes.guess_type(path)[0] or "image/png"
    data = base64.b64encode(Path(path).read_bytes()).decode("ascii")
    return f"data:{mime};base64,{data}"


def build_messages(question: dict, image_path: str = "") -> list[dict]:
    text = format_question(question)
    if image_path:
        content = [{"type": "text", "text": text + "\n（题目内容见附图，请先识别图中的题目文字再讲解。）"},
                   {"type": "image_url", "image_url": {"url": image_data_url(image_path)}}]
    else:
        content = text
    return [{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": content}]


def split_answer(text: str) -> tuple[str, str]:
    """Model output -> (analysis, reference answer). Falls back to all-analysis."""
    match = ANSWER_HEADING_RE.search(text or "")
    if not match:
        return (text or "").strip(), ""
    analysis = text[:match.start()]
    analysis = re.sub(r"^\s*(?:#+\s*)?(?:\*\*)?\s*解析\s*(?:\*\*)?\s*[:：]?\s*", "", analysis, count=1)
    return analysis.strip(), text[match.end():].strip()


# ---------------------------------------------------------------- HTTP client
class AiError(RuntimeError):
    pass


def _open(url: str, payload: dict | None = None, timeout: float = 10.0):
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        return urllib.request.urlopen(req, timeout=timeout)  # noqa: S310 - local / user-configured URL
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")[:300]
        raise AiError(f"HTTP {exc.code}：{_error_message(body) or exc.reason}") from exc
    except urllib.error.URLError as exc:
        raise AiError(f"无法连接到模型服务（{exc.reason}）") from exc
    except TimeoutError as exc:
        raise AiError("连接模型服务超时") from exc


def _error_message(body: str) -> str:
    try:
        data = json.loads(body)
    except ValueError:
        return body.strip()
    err = data.get("error")
    if isinstance(err, dict):
        return str(err.get("message") or "")
    return str(err or data.get("message") or "")


def health(base_url: str, timeout: float = 3.0) -> str:
    """'ok', 'loading' or raises AiError."""
    try:
        with _open(base_url + "/health", timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8") or "{}")
            return "ok" if data.get("status", "ok") == "ok" else str(data.get("status"))
    except AiError as exc:
        if "HTTP 503" in str(exc):
            return "loading"
        raise


def model_name(base_url: str) -> str:
    try:
        with _open(base_url + "/v1/models", timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8") or "{}")
    except (AiError, ValueError):
        return ""
    items = data.get("data") or data.get("models") or []
    if items and isinstance(items[0], dict):
        return Path(str(items[0].get("id") or items[0].get("name") or "")).name
    return ""


def iter_sse(lines: Iterable[bytes]) -> Iterator[dict]:
    """Decode an OpenAI-style server-sent-event stream into JSON chunks."""
    for raw in lines:
        line = raw.decode("utf-8", errors="replace").strip()
        if not line.startswith("data:"):
            continue
        payload = line[5:].strip()
        if payload == "[DONE]":
            return
        try:
            yield json.loads(payload)
        except ValueError:
            continue


def stream_chat(base_url: str, messages: list[dict], settings: AiSettings,
                cancel: threading.Event | None = None, timeout: float = 300.0) -> Iterator[str]:
    """Yield content deltas from /v1/chat/completions (stream=true)."""
    payload = {"messages": messages, "stream": True, "temperature": settings.temperature,
               "max_tokens": settings.max_tokens}
    with _open(base_url + "/v1/chat/completions", payload, timeout=timeout) as resp:
        for chunk in iter_sse(resp):
            if cancel is not None and cancel.is_set():
                return
            if "error" in chunk:
                raise AiError(_error_message(json.dumps(chunk)) or "模型返回错误")
            for choice in chunk.get("choices") or []:
                delta = (choice.get("delta") or {}).get("content") or ""
                if delta:
                    yield delta


def quick_test(base_url: str, settings: AiSettings) -> dict:
    """Connection test: health, model name, and a tiny completion with timing."""
    status = health(base_url)
    if status != "ok":
        raise AiError("模型仍在加载，请稍后再测试" if status == "loading" else f"服务状态：{status}")
    name = model_name(base_url)
    t0 = time.monotonic()
    tiny = AiSettings(**{**asdict(settings), "max_tokens": 16, "temperature": 0})
    reply = "".join(stream_chat(base_url, [{"role": "user", "content": "请只回复：连接正常"}], tiny, timeout=60))
    return {"model": name, "reply": reply.strip(), "seconds": round(time.monotonic() - t0, 2)}


# ---------------------------------------------------------------- review history
@dataclass
class ReviewItem:
    id: str
    created: str
    question: str
    analysis: str
    answer: str
    model: str = ""
    status: str = "pending"        # pending | approved | rejected
    note: str = ""


class ReviewStore:
    """Local history of generated explanations and the user's review decisions."""

    def __init__(self, folder: Path | None = None) -> None:
        self.path = (folder or DATA_DIR) / HISTORY_FILE
        self.items: list[ReviewItem] = []
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
            names = {f.name for f in fields(ReviewItem)}
            self.items = [ReviewItem(**{k: v for k, v in r.items() if k in names}) for r in raw if isinstance(r, dict)]
        except (OSError, ValueError, TypeError):
            self.items = []

    def add(self, question: str, analysis: str, answer: str, model: str = "") -> ReviewItem:
        item = ReviewItem(id=uuid.uuid4().hex[:12], created=time.strftime("%Y-%m-%d %H:%M"),
                          question=question, analysis=analysis, answer=answer, model=model)
        self.items.insert(0, item)
        del self.items[HISTORY_LIMIT:]
        self.save()
        return item

    def review(self, item_id: str, status: str, note: str = "") -> ReviewItem | None:
        if status not in ("pending", "approved", "rejected"):
            raise ValueError(status)
        for item in self.items:
            if item.id == item_id:
                item.status = status
                item.note = note
                self.save()
                return item
        return None

    def get(self, item_id: str) -> ReviewItem | None:
        return next((i for i in self.items if i.id == item_id), None)

    def clear(self) -> None:
        self.items = []
        self.save()

    def save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(json.dumps([asdict(i) for i in self.items], ensure_ascii=False, indent=1), encoding="utf-8")


def is_frozen() -> bool:
    return bool(getattr(sys, "frozen", False))
