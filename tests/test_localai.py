import base64
import os
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

from PySide6.QtCore import QCoreApplication, QEventLoop, QTimer

from ui import localai

app = QCoreApplication.instance() or QCoreApplication([])
FAKE = Path(__file__).resolve().parent / "fake_llama_server.py"


def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def fake_exe(folder: Path) -> Path:
    """A llama-server.cmd that runs the fake server with the same arguments."""
    exe = folder / "llama-server.cmd"
    # cmd.exe reads batch files in the system code page, not UTF-8 (the project path is Chinese).
    exe.write_text(f'@echo off\r\n"{sys.executable}" "{FAKE}" %*\r\n', encoding="mbcs")
    return exe


def wait_for(cond, seconds=20.0) -> bool:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if cond():
            return True
        loop = QEventLoop()
        QTimer.singleShot(50, loop.quit)
        loop.exec()
    return cond()


class PureFunctionsTestCase(unittest.TestCase):
    def test_settings_roundtrip_and_bad_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            s = localai.AiSettings(model_path="m.gguf", port=9000, temperature=0.5)
            s.save(Path(tmp))
            loaded = localai.AiSettings.load(Path(tmp))
            self.assertEqual((loaded.model_path, loaded.port, loaded.temperature), ("m.gguf", 9000, 0.5))
            (Path(tmp) / localai.SETTINGS_FILE).write_text('{"port": "x", "unknown": 1, "ctx_size": "2048"}', encoding="utf-8")
            loaded = localai.AiSettings.load(Path(tmp))
            self.assertEqual((loaded.port, loaded.ctx_size), (8089, 2048))

    def test_validate(self):
        with tempfile.TemporaryDirectory() as tmp:
            model = Path(tmp) / "q.gguf"
            model.write_bytes(b"GGUF")
            ok = localai.AiSettings(model_path=str(model))
            self.assertEqual(localai.validate(ok, managed=True), [])
            self.assertIn("还没有选择 GGUF 模型文件", localai.validate(localai.AiSettings(), managed=True))
            bad = localai.AiSettings(model_path=str(model), mmproj_path=str(Path(tmp) / "none.gguf"), port=70000)
            problems = localai.validate(bad, managed=True)
            self.assertIn("找不到 mmproj 文件", problems)
            self.assertIn("端口需要在 1–65535 之间", problems)
            self.assertTrue(localai.validate(localai.AiSettings(external_url="localhost:8080"), managed=False))
            self.assertEqual(localai.validate(localai.AiSettings(external_url="http://127.0.0.1:8080"), managed=False), [])

    def test_build_server_args(self):
        s = localai.AiSettings(model_path="C:/m/q.gguf", mmproj_path="C:/m/mm.gguf", port=9001, ctx_size=8192,
                               gpu_layers=33, threads=6, extra_args="--flash-attn on")
        args = localai.build_server_args(s)
        self.assertEqual(args[:2], ["-m", "C:/m/q.gguf"])
        for pair in (["--port", "9001"], ["-c", "8192"], ["-ngl", "33"], ["--mmproj", "C:/m/mm.gguf"], ["-t", "6"]):
            i = args.index(pair[0])
            self.assertEqual(args[i:i + 2], pair)
        self.assertEqual(args[-2:], ["--flash-attn", "on"])
        self.assertNotIn("--mmproj", localai.build_server_args(localai.AiSettings(model_path="a.gguf")))

    def test_parse_pasted_and_format(self):
        q = localai.parse_pasted("质点做匀速圆周运动时，\n下列哪个量保持不变？\nA. 速度\nB、加速度\nC) 速率\n  （标量）\nD：位移")
        self.assertEqual(q["title"], "质点做匀速圆周运动时，\n下列哪个量保持不变？")
        self.assertEqual(q["options"], ["A. 速度", "B. 加速度", "C. 速率 （标量）", "D. 位移"])
        self.assertEqual(q["type"], "选择题")
        self.assertEqual(localai.parse_pasted("加速度为零的物体一定静止。（对 / 错）")["type"], "判断题")
        text = localai.format_question(q)
        self.assertIn("选项：", text)
        self.assertIn("C. 速率", text)

    def test_course_context_in_prompt(self):
        text = localai.format_question({"course": "大学物理（上）", "chapter": "1.2 章节检测", "type": "单选题",
                                        "title": "t", "options": []})
        self.assertTrue(text.startswith("课程：大学物理（上）\n章节：1.2 章节检测\n题型：单选题"))
        self.assertNotIn("课程：", localai.format_question({"title": "t"}))

    def test_question_from_work(self):
        item = {"typeLabel": "单选题", "title": " 题干 ", "options": [{"text": "A. 一", "selected": True}, {"text": "B. 二"}]}
        self.assertEqual(localai.question_from_work(item), {"type": "单选题", "title": "题干", "options": ["A. 一", "B. 二"]})

    def test_build_messages_with_image(self):
        with tempfile.TemporaryDirectory() as tmp:
            img = Path(tmp) / "q.png"
            img.write_bytes(b"\x89PNG fake")
            msgs = localai.build_messages({"title": "", "options": []}, str(img))
            self.assertEqual(msgs[0]["role"], "system")
            parts = msgs[1]["content"]
            self.assertEqual(parts[1]["type"], "image_url")
            self.assertTrue(parts[1]["image_url"]["url"].startswith("data:image/png;base64,"))
            self.assertEqual(base64.b64decode(parts[1]["image_url"]["url"].split(",", 1)[1]), b"\x89PNG fake")

    def test_split_answer(self):
        analysis, answer = localai.split_answer("## 解析\n思路……\n## 参考答案\nC")
        self.assertEqual((analysis, answer), ("思路……", "C"))
        self.assertEqual(localai.split_answer("**参考答案：** B\n理由"), ("", "B\n理由"))
        self.assertEqual(localai.split_answer("只有解析"), ("只有解析", ""))

    def test_iter_sse(self):
        lines = [b": comment\n", b'data: {"choices":[{"delta":{"content":"a"}}]}\n', b"\n",
                 b"data: not-json\n", b'data: {"choices":[{"delta":{"content":"b"}}]}\n', b"data: [DONE]\n",
                 b'data: {"choices":[{"delta":{"content":"after"}}]}\n']
        chunks = list(localai.iter_sse(lines))
        self.assertEqual([c["choices"][0]["delta"]["content"] for c in chunks], ["a", "b"])

    def test_detect_with_fake_exe(self):
        with tempfile.TemporaryDirectory() as tmp:
            exe = fake_exe(Path(tmp))
            path, version = localai.detect_server(str(exe))
            self.assertEqual(path, exe)
            self.assertEqual(version, "b4321 (abc1234)")
            self.assertIsNone(localai.probe_version(Path(tmp) / "missing.exe"))

    def test_review_store(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = localai.ReviewStore(Path(tmp))
            item = store.add("题目", "解析", "C", "m.gguf")
            self.assertEqual(item.status, "pending")
            store.review(item.id, "approved", "核对过")
            again = localai.ReviewStore(Path(tmp))
            self.assertEqual((again.items[0].status, again.items[0].note), ("approved", "核对过"))
            with self.assertRaises(ValueError):
                store.review(item.id, "submitted")
            for i in range(localai.HISTORY_LIMIT + 5):
                store.add(str(i), "", "")
            self.assertEqual(len(store.items), localai.HISTORY_LIMIT)


class FakeServerHttpTestCase(unittest.TestCase):
    """HTTP client against a running fake server."""

    @classmethod
    def setUpClass(cls):
        cls.port = free_port()
        env = dict(os.environ, FAKE_LLAMA_LOAD_SECONDS="0.8")
        cls.proc = subprocess.Popen([sys.executable, str(FAKE), "--port", str(cls.port), "-m", "D:/x/qwen.gguf"],
                                    env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        cls.base = f"http://127.0.0.1:{cls.port}"
        deadline = time.monotonic() + 10
        cls.saw_loading = False
        while time.monotonic() < deadline:
            try:
                status = localai.health(cls.base, timeout=1)
            except localai.AiError:
                time.sleep(0.05)
                continue
            if status == "loading":
                cls.saw_loading = True
                time.sleep(0.1)
                continue
            break

    @classmethod
    def tearDownClass(cls):
        cls.proc.kill()
        cls.proc.wait(5)

    def test_health_model_and_stream(self):
        self.assertTrue(self.saw_loading, "fake server should report loading (503) first")
        self.assertEqual(localai.health(self.base), "ok")
        self.assertEqual(localai.model_name(self.base), "qwen.gguf")
        text = "".join(localai.stream_chat(self.base, localai.build_messages({"title": "t", "options": []}),
                                           localai.AiSettings()))
        self.assertIn("## 参考答案", text)
        self.assertEqual(localai.split_answer(text)[1].split("——")[0], "C. 速率")

    def test_quick_test(self):
        info = localai.quick_test(self.base, localai.AiSettings())
        self.assertEqual(info["model"], "qwen.gguf")
        self.assertEqual(info["reply"], "连接正常")

    def test_unreachable(self):
        with self.assertRaises(localai.AiError) as ctx:
            localai.health(f"http://127.0.0.1:{free_port()}", timeout=1)
        self.assertIn("无法连接", str(ctx.exception))


class ManagedServerEndToEndTestCase(unittest.TestCase):
    """LocalAI (the QML-facing object): detect, start, wait for health, test, explain, review, stop."""

    def test_full_flow(self):
        from ui.assistant import LocalAI

        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            model = folder / "tiny-q4.gguf"
            model.write_bytes(b"GGUF")
            ai = LocalAI(controller=None, data_dir=folder)
            ai.setSetting("server_path", str(fake_exe(folder)))
            ai.setSetting("model_path", str(model))
            ai.setSetting("port", free_port())
            toasts = []
            ai.toast.connect(lambda m, k: toasts.append((k, m)))

            ai.detect()
            self.assertTrue(wait_for(lambda: ai.detectState in ("found", "missing")))
            self.assertEqual((ai.detectState, ai.serverVersion), ("found", "b4321 (abc1234)"))

            # Explaining before the server runs is refused, not attempted.
            ai.explainText("1+1=?", "")
            self.assertFalse(ai.busy)
            self.assertIn(("warning", "请先启动或连接模型服务"), toasts)

            ai.startServer()
            self.assertEqual(ai.serverState, "starting")
            self.assertTrue(wait_for(lambda: ai.serverState in ("running", "error"), 30), ai.serverMessage)
            self.assertEqual(ai.serverState, "running", ai.serverMessage)
            self.assertEqual(ai.modelName, "tiny-q4.gguf")

            ai.testConnection()
            self.assertTrue(wait_for(lambda: any("连接正常" in m for _, m in toasts)))

            ai.explainText("质点做匀速圆周运动时，下列哪个量保持不变？\nA. 速度\nB. 加速度\nC. 速率\nD. 位移", "")
            self.assertTrue(ai.busy)
            self.assertTrue(wait_for(lambda: not ai.busy, 20))
            self.assertEqual(ai.errorText, "")
            self.assertIn("速度方向时刻改变", ai.analysis)
            self.assertTrue(ai.answer.startswith("C. 速率"))
            item_id = ai.currentId
            self.assertTrue(item_id)
            self.assertEqual(ai.history[0]["status"], "pending")

            # Human review gate: pending answers cannot be copied; approved ones can.
            self.assertFalse(ai.copyAnswer(item_id))
            ai.review(item_id, "approved", "已核对教材")
            self.assertEqual(ai.history[0]["status"], "approved")
            self.assertEqual(ai.history[0]["note"], "已核对教材")

            log = ai.logModel.visibleText()
            self.assertIn("找到 llama-server", log)
            self.assertIn("模型服务就绪", log)
            self.assertIn("推理完成", log)
            self.assertNotIn(str(folder), log, "log must not contain full local paths")

            ai.stopServer()
            self.assertEqual(ai.serverState, "stopped")
            ai.shutdown()

    def test_bad_settings_and_server_crash(self):
        from ui.assistant import LocalAI

        with tempfile.TemporaryDirectory() as tmp:
            folder = Path(tmp)
            ai = LocalAI(controller=None, data_dir=folder)
            ai.startServer()
            self.assertEqual(ai.serverState, "error")
            self.assertIn("还没有选择 GGUF 模型文件", ai.serverMessage)

            # A "server" that exits right away -> error state with the exit code.
            crash = folder / "llama-server.cmd"
            crash.write_text("@echo off\r\necho error: failed to load model\r\nexit /b 3\r\n", encoding="mbcs")
            model = folder / "m.gguf"
            model.write_bytes(b"GGUF")
            ai.setSetting("server_path", str(crash))
            ai.setSetting("model_path", str(model))
            ai.setSetting("port", free_port())
            ai.startServer()
            self.assertTrue(wait_for(lambda: ai.serverState == "error", 15))
            self.assertIn("已退出", ai.serverMessage)
            self.assertIn("failed to load model", ai.logModel.visibleText())
            ai.shutdown()

    def test_inference_error_is_reported(self):
        from ui.assistant import LocalAI

        port = free_port()
        env = dict(os.environ, FAKE_LLAMA_LOAD_SECONDS="0", FAKE_LLAMA_FAIL="1")
        proc = subprocess.Popen([sys.executable, str(FAKE), "--port", str(port)], env=env,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            with tempfile.TemporaryDirectory() as tmp:
                ai = LocalAI(controller=None, data_dir=Path(tmp))
                ai.setSetting("external_url", f"http://127.0.0.1:{port}")
                ai.startServer()
                self.assertTrue(wait_for(lambda: ai.serverState == "running", 15), ai.serverMessage)
                ai.explainText("1+1=?", "")
                self.assertTrue(wait_for(lambda: not ai.busy, 15))
                self.assertIn("fake inference failure", ai.errorText)
                self.assertEqual(ai.currentId, "")
                self.assertEqual(ai.history, [])
                ai.shutdown()
        finally:
            proc.kill()
            proc.wait(5)


if __name__ == "__main__":
    unittest.main()
