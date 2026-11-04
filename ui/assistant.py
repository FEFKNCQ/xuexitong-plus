# -*- coding: utf-8 -*-
"""Qt side of the local AI tutor (exposed to QML as ``ai``). See ui/localai.py for scope."""

from __future__ import annotations

import os
import subprocess
import threading
import time
from dataclasses import asdict
from pathlib import Path

from PySide6.QtCore import Property, QObject, QProcess, QThread, QTimer, Signal, Slot
from PySide6.QtGui import QGuiApplication

from ui import localai
from ui.models import LogModel

HEALTH_TIMEOUT_S = 240   # big models can take minutes to load


class _Job(QThread):
    """Run ``fn(emit_chunk)`` off the UI thread."""

    chunk = Signal(str)
    done = Signal(object)
    failed = Signal(str)

    def __init__(self, fn) -> None:
        super().__init__()
        self._fn = fn

    def run(self) -> None:
        try:
            self.done.emit(self._fn(self.chunk.emit))
        except localai.AiError as exc:
            self.failed.emit(str(exc))
        except Exception as exc:  # surfaced in the UI, never crashes the app
            self.failed.emit(f"{type(exc).__name__}: {exc}")


class LocalAI(QObject):
    settingsChanged = Signal()
    detectChanged = Signal()
    serverChanged = Signal()
    outputChanged = Signal()
    historyChanged = Signal()
    toast = Signal(str, str)

    def __init__(self, controller=None, data_dir: Path | None = None, parent=None) -> None:
        super().__init__(parent)
        self._controller = controller
        self._data_dir = data_dir or localai.DATA_DIR
        self._settings = localai.AiSettings.load(self._data_dir)
        if controller is not None:
            controller.dashboardChanged.connect(self.contextChanged)
            controller.workChanged.connect(self.contextChanged)
            controller.coursesChanged.connect(self.contextChanged)
            controller.configChanged.connect(self.contextChanged)
        self._store = localai.ReviewStore(self._data_dir)
        self._log = LogModel(limit=600, parent=self)
        self._jobs: set[_Job] = set()

        self._detect_state = "idle"     # idle | detecting | found | missing
        self._server_exe = ""
        self._server_version = ""

        self._server_state = "stopped"  # stopped | starting | running | error
        self._server_message = ""
        self._model = ""
        self._process: QProcess | None = None
        self._health_deadline = 0.0
        self._health_timer = QTimer(self)
        self._health_timer.setInterval(1000)
        self._health_timer.timeout.connect(self._poll_health)
        self._health_busy = False

        self._busy = False
        self._cancel = threading.Event()
        self._output = ""
        self._error = ""
        self._current_id = ""
        self._question_text = ""

    # ------------------------------------------------------------ helpers
    def _log_line(self, level: str, message: str) -> None:
        self._log.append(level, message, time.strftime("%H:%M:%S"))

    def _start_job(self, fn, on_done, on_failed, on_chunk=None) -> _Job:
        job = _Job(fn)
        if on_chunk:
            job.chunk.connect(on_chunk)
        job.done.connect(on_done)
        job.failed.connect(on_failed)
        job.finished.connect(lambda: (self._jobs.discard(job), job.deleteLater()))
        self._jobs.add(job)
        job.start()
        return job

    @property
    def _managed(self) -> bool:
        return not self._settings.external_url.strip()

    # ------------------------------------------------------------ settings
    def _settings_map(self) -> dict:
        return asdict(self._settings)

    settings = Property("QVariantMap", _settings_map, notify=settingsChanged)
    logModel = Property(QObject, lambda self: self._log, constant=True)
    baseUrl = Property(str, lambda self: self._settings.base_url, notify=settingsChanged)
    managed = Property(bool, lambda self: self._managed, notify=settingsChanged)

    @Slot(str, "QVariant")
    def setSetting(self, key: str, value) -> None:
        if not hasattr(self._settings, key):
            return
        current = getattr(self._settings, key)
        try:
            value = type(current)(value)
        except (TypeError, ValueError):
            return
        if value != current:
            setattr(self._settings, key, value)
            self._settings.save(self._data_dir)
            self.settingsChanged.emit()

    @Slot(str, result=str)
    def browse(self, kind: str) -> str:
        """File picker for 'server' / 'model' / 'mmproj'; stores and returns the chosen path."""
        from PySide6.QtWidgets import QFileDialog

        filters = {
            "server": "llama-server (llama-server.exe llama-server);;所有文件 (*)",
            "model": "GGUF 模型 (*.gguf);;所有文件 (*)",
            "mmproj": "mmproj 投影模型 (*.gguf);;所有文件 (*)",
        }
        key = {"server": "server_path", "model": "model_path", "mmproj": "mmproj_path"}.get(kind)
        if key is None:
            return ""
        start = getattr(self._settings, key) or str(Path.home())
        path, _ = QFileDialog.getOpenFileName(None, "选择文件", start, filters[kind])
        if path:
            self.setSetting(key, str(Path(path)))
        return path

    @Slot(str)
    def clearSetting(self, key: str) -> None:
        if hasattr(self._settings, key) and isinstance(getattr(self._settings, key), str):
            self.setSetting(key, "")

    @Slot(result="QStringList")
    def validationProblems(self) -> list[str]:
        return localai.validate(self._settings, managed=self._managed)

    # ------------------------------------------------------------ detection
    detectState = Property(str, lambda self: self._detect_state, notify=detectChanged)
    serverExe = Property(str, lambda self: self._server_exe, notify=detectChanged)
    serverVersion = Property(str, lambda self: self._server_version, notify=detectChanged)

    @Slot()
    def detect(self) -> None:
        if self._detect_state == "detecting":
            return
        self._detect_state = "detecting"
        self.detectChanged.emit()
        configured = self._settings.server_path
        self._log_line("INFO", "正在检测 llama-server…")

        def work(_emit):
            return localai.detect_server(configured)

        def done(result):
            path, version = result
            self._server_exe = str(path) if path else ""
            self._server_version = version or ""
            self._detect_state = "found" if path else "missing"
            self.detectChanged.emit()
            if path:
                self._log_line("SUCCESS", f"找到 llama-server {self._server_version}：{path.name}")
            else:
                self._log_line("WARNING", "没有找到可用的 llama-server。请在设置里选择 llama-server.exe，或填写已运行服务的地址。")

        def failed(msg):
            self._detect_state = "missing"
            self.detectChanged.emit()
            self._log_line("ERROR", f"检测失败：{msg}")

        self._start_job(work, done, failed)

    # ------------------------------------------------------------ server
    serverState = Property(str, lambda self: self._server_state, notify=serverChanged)
    serverMessage = Property(str, lambda self: self._server_message, notify=serverChanged)
    modelName = Property(str, lambda self: self._model, notify=serverChanged)

    def _set_server(self, state: str, message: str = "") -> None:
        self._server_state = state
        self._server_message = message
        self.serverChanged.emit()

    @Slot()
    def startServer(self) -> None:
        if self._server_state in ("starting", "running"):
            return
        problems = localai.validate(self._settings, managed=self._managed)
        if problems:
            self._set_server("error", "；".join(problems))
            self._log_line("ERROR", "无法启动：" + "；".join(problems))
            return
        if not self._managed:
            self._log_line("INFO", f"连接外部服务 {self._settings.base_url}")
            self._set_server("starting", "正在连接外部服务…")
            self._health_deadline = time.monotonic() + 15
            self._health_timer.start()
            return
        exe = self._settings.server_path or self._server_exe
        if not exe:
            path, version = localai.detect_server("")
            if path:
                exe, self._server_exe, self._server_version = str(path), str(path), version or ""
                self._detect_state = "found"
                self.detectChanged.emit()
        if not exe or not Path(exe).exists():
            self._set_server("error", "没有找到 llama-server，请先在模型设置里选择")
            self._log_line("ERROR", "没有找到 llama-server")
            return
        args = localai.build_server_args(self._settings)
        process = QProcess(self)
        process.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        process.readyReadStandardOutput.connect(self._read_server_output)
        process.finished.connect(self._on_server_finished)
        process.errorOccurred.connect(self._on_server_error)
        process.setWorkingDirectory(str(Path(exe).parent))
        self._log_line("INFO", f"启动 {Path(exe).name} " + " ".join(_display_args(args)))
        process.start(exe, args)
        self._process = process
        self._model = Path(self._settings.model_path).name
        self._set_server("starting", "正在加载模型…")
        self._health_deadline = time.monotonic() + HEALTH_TIMEOUT_S
        self._health_timer.start()

    @Slot()
    def stopServer(self) -> None:
        self._health_timer.stop()
        self.cancel()
        if self._process is not None and self._process.state() != QProcess.ProcessState.NotRunning:
            self._log_line("INFO", "正在停止 llama-server…")
            _kill_tree(self._process.processId())
            if not self._process.waitForFinished(3000):
                self._process.kill()
                self._process.waitForFinished(2000)
        self._process = None
        self._set_server("stopped", "")

    def _read_server_output(self) -> None:
        if self._process is None:
            return
        text = bytes(self._process.readAllStandardOutput()).decode("utf-8", errors="replace")
        for line in text.splitlines():
            line = line.strip()
            if not line:
                continue
            lower = line.lower()
            level = "ERROR" if ("error" in lower or "failed" in lower) else "WARNING" if "warn" in lower else "INFO"
            self._log_line(level, "[server] " + line[:400])

    def _on_server_finished(self, code: int, _status) -> None:
        self._health_timer.stop()
        if self._process is not None:
            self._read_server_output()
        self._process = None
        if self._server_state != "stopped":
            self._set_server("error", f"llama-server 已退出（代码 {code}），请查看推理日志")
            self._log_line("ERROR", f"llama-server 已退出，代码 {code}")

    def _on_server_error(self, error) -> None:
        if error == QProcess.ProcessError.FailedToStart:
            self._health_timer.stop()
            self._process = None
            self._set_server("error", "llama-server 无法启动（文件不可执行或缺少依赖）")
            self._log_line("ERROR", "llama-server 无法启动")

    def _poll_health(self) -> None:
        if self._health_busy:
            return
        if time.monotonic() > self._health_deadline:
            self._health_timer.stop()
            self._set_server("error", "等待模型就绪超时")
            self._log_line("ERROR", "等待模型就绪超时")
            return
        self._health_busy = True
        base = self._settings.base_url

        def work(_emit):
            status = localai.health(base, timeout=2)
            return status, (localai.model_name(base) if status == "ok" else "")

        def done(result):
            self._health_busy = False
            status, name = result
            if self._server_state != "starting":
                return
            if status == "ok":
                self._health_timer.stop()
                self._model = name or self._model
                self._set_server("running", "外部服务已连接" if not self._managed else "模型已就绪")
                self._log_line("SUCCESS", f"模型服务就绪：{self._model or base}")

        def failed(_msg):
            self._health_busy = False   # not up yet; keep polling until the deadline

        self._start_job(work, done, failed)

    # ------------------------------------------------------------ connection test
    @Slot()
    def testConnection(self) -> None:
        base, settings = self._settings.base_url, localai.AiSettings(**asdict(self._settings))
        self._log_line("INFO", f"连接测试：{base}")

        def done(info):
            self._model = info.get("model") or self._model
            self.serverChanged.emit()
            msg = f"连接正常，用时 {info['seconds']} 秒" + (f"，模型 {info['model']}" if info.get("model") else "")
            self._log_line("SUCCESS", msg + (f"，回复：{info['reply'][:40]}" if info.get("reply") else ""))
            self.toast.emit(msg, "info")

        def failed(msg):
            self._log_line("ERROR", f"连接测试失败：{msg}")
            self.toast.emit(f"连接测试失败：{msg}", "error")

        self._start_job(lambda _e: localai.quick_test(base, settings), done, failed)

    # ------------------------------------------------------------ inference
    busy = Property(bool, lambda self: self._busy, notify=outputChanged)
    output = Property(str, lambda self: self._output, notify=outputChanged)
    errorText = Property(str, lambda self: self._error, notify=outputChanged)
    analysis = Property(str, lambda self: localai.split_answer(self._output)[0], notify=outputChanged)
    answer = Property(str, lambda self: localai.split_answer(self._output)[1], notify=outputChanged)
    thinking = Property(int, lambda self: getattr(self, "_thinking", 0), notify=outputChanged)
    currentId = Property(str, lambda self: self._current_id, notify=outputChanged)
    questionText = Property(str, lambda self: self._question_text, notify=outputChanged)

    # Current course / chapter, recognised from the run dashboard (the task worker's log).
    contextChanged = Signal()

    def _course(self) -> str:
        # The course being studied right now; otherwise the courses picked via "识别课程".
        current = str(getattr(self._controller, "_course", "") or "")
        if current or self._controller is None:
            return current
        return "、".join(self._controller.selected_course_names())

    def _chapter(self) -> str:
        work = getattr(self._controller, "_work", None) or {}
        return str(work.get("title") or getattr(self._controller, "_chapter", "") or "")

    courseName = Property(str, _course, notify=contextChanged)
    chapterName = Property(str, _chapter, notify=contextChanged)

    def _with_context(self, question: dict) -> dict:
        return {**question, "course": self._course(), "chapter": self._chapter()}

    def _work_questions(self) -> list[dict]:
        work = getattr(self._controller, "_work", None) or {}
        return list(work.get("questions") or [])

    @Slot(int)
    def explainWork(self, index: int) -> None:
        questions = self._work_questions()
        if not 0 <= index < len(questions):
            self.toast.emit("当前没有可讲解的章节检测题目", "warning")
            return
        self._explain(self._with_context(localai.question_from_work(questions[index])))

    @Slot(str, str)
    def explainText(self, text: str, image_path: str = "") -> None:
        if not text.strip() and not image_path:
            self.toast.emit("请先输入题目或选择图片", "warning")
            return
        self._explain(self._with_context(localai.parse_pasted(text)), image_path)

    @Slot(result=str)
    def browseImage(self) -> str:
        from PySide6.QtWidgets import QFileDialog

        path, _ = QFileDialog.getOpenFileName(None, "选择题目图片", str(Path.home()), "图片 (*.png *.jpg *.jpeg *.bmp *.webp)")
        return path

    def _explain(self, question: dict, image_path: str = "") -> None:
        if self._busy:
            return
        if self._server_state != "running":
            self.toast.emit("请先启动或连接模型服务", "warning")
            return
        if image_path and self._managed and not self._settings.mmproj_path:
            self.toast.emit("图片题需要在模型设置里配置 mmproj 文件", "warning")
            return
        try:
            messages = localai.build_messages(question, image_path)
        except OSError as exc:
            self.toast.emit(f"读取图片失败：{exc}", "error")
            return
        self._question_text = localai.format_question(question) + ("\n（附图）" if image_path else "")
        self._output = ""
        self._thinking = 0
        self._error = ""
        self._current_id = ""
        self._busy = True
        self._cancel.clear()
        self.outputChanged.emit()
        base, settings, cancel = self._settings.base_url, localai.AiSettings(**asdict(self._settings)), self._cancel
        started = time.monotonic()
        self._log_line("INFO", f"开始推理（{len(question.get('options') or [])} 个选项{'，含图片' if image_path else ''}）")

        def work(emit):
            for delta in localai.stream_chat(base, messages, settings, cancel=cancel,
                                             on_reasoning=lambda n: emit(("thinking", n))):
                emit(delta)
            return cancel.is_set()

        def on_chunk(delta):
            if isinstance(delta, tuple):          # reasoning model still thinking
                self._thinking = delta[1]
            else:
                self._output += delta
            self.outputChanged.emit()

        def done(cancelled):
            self._busy = False
            seconds = max(0.01, time.monotonic() - started)
            if cancelled:
                self._log_line("WARNING", "已取消推理")
            elif localai.strip_thinking(self._output).strip():
                analysis, answer = localai.split_answer(self._output)
                item = self._store.add(self._question_text, analysis, answer, self._model)
                self._current_id = item.id
                self.historyChanged.emit()
                self._log_line("SUCCESS", f"推理完成，{len(self._output)} 字，用时 {seconds:.1f} 秒（约 {len(self._output) / seconds:.0f} 字/秒），等待人工审核")
            elif self._thinking:
                self._error = (f"模型思考了 {self._thinking} 字，用完了最大输出 token（{settings.max_tokens}）还没写出答案。"
                               "请在“模型设置”里调大“最大输出 token”后重试")
                self._log_line("WARNING", self._error)
            else:
                self._error = "模型没有返回内容"
                self._log_line("WARNING", self._error)
            self.outputChanged.emit()

        def failed(msg):
            self._busy = False
            self._error = msg
            self._log_line("ERROR", f"推理失败：{msg}")
            self.outputChanged.emit()

        self._start_job(work, done, failed, on_chunk)

    @Slot()
    def cancel(self) -> None:
        if self._busy:
            self._cancel.set()

    # ------------------------------------------------------------ review
    def _history(self) -> list[dict]:
        return [asdict(i) for i in self._store.items]

    history = Property("QVariantList", _history, notify=historyChanged)

    @Slot(str, str, str)
    def review(self, item_id: str, status: str, note: str = "") -> None:
        item = self._store.review(item_id, status, note)
        if item is not None:
            self._log_line("INFO", f"人工审核：{ {'approved': '采纳', 'rejected': '有误', 'pending': '待审核'}[status] }")
            self.historyChanged.emit()

    @Slot(str, result=bool)
    def copyAnswer(self, item_id: str) -> bool:
        """Copy a reviewed answer. Only answers the user marked 采纳 can be copied."""
        item = self._store.get(item_id)
        if item is None or item.status != "approved":
            self.toast.emit("请先审核：只有标记为“采纳”的答案可以复制", "warning")
            return False
        QGuiApplication.clipboard().setText(f"{item.question}\n\n解析：{item.analysis}\n\n参考答案：{item.answer}")
        self.toast.emit("已复制解析和参考答案", "info")
        return True

    @Slot()
    def clearHistory(self) -> None:
        self._store.clear()
        self._current_id = ""
        self.historyChanged.emit()
        self.outputChanged.emit()

    def shutdown(self) -> None:
        self.stopServer()
        for job in list(self._jobs):
            job.wait(3000)


def _kill_tree(pid: int) -> None:
    """End the server and anything it started (a wrapper script may leave the real server behind)."""
    if not pid:
        return
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True,
                       creationflags=localai.CREATE_NO_WINDOW, timeout=15)
    else:
        try:
            os.kill(pid, 15)
        except OSError:
            pass


def _display_args(args: list[str]) -> list[str]:
    """Show file names instead of full paths in the log (screenshots, privacy)."""
    out = []
    for arg in args:
        out.append(Path(arg).name if ("\\" in arg or "/" in arg) else arg)
    return out
