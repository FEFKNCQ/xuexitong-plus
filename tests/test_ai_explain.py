import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from ui import localai


class PromptTest(unittest.TestCase):
    def test_type_hint_and_context(self):
        text = localai.format_question({"course": "戏曲鉴赏", "chapter": "3.1 认识越剧", "type": "多选题",
                                        "title": "越剧吸收了哪些剧种？", "options": ["A 昆曲", "B 话剧"]})
        self.assertIn("课程：戏曲鉴赏", text)
        self.assertIn("题型：多选题（有两个或以上正确选项", text)
        self.assertIn("  A 昆曲", text)
        self.assertNotIn("（", localai.format_question({"type": "题目", "title": "t"}).split("\n")[0])

    def test_prompt_keeps_the_headings_the_parser_needs(self):
        self.assertIn("## 解析", localai.SYSTEM_PROMPT)
        self.assertIn("## 参考答案", localai.SYSTEM_PROMPT)

    def test_inline_thinking_is_dropped(self):
        text = "<think>参考答案应该是 B 吗？再想想……</think>\n## 解析\n考点：越剧起源。\n## 参考答案\nA 浙江嵊州"
        self.assertEqual(localai.split_answer(text), ("考点：越剧起源。", "A 浙江嵊州"))
        # Still thinking (no closing tag yet) -> nothing to show.
        self.assertEqual(localai.split_answer("<think>正在想"), ("", ""))


class ReasoningStreamTest(unittest.TestCase):
    def test_reasoning_is_reported_not_returned(self):
        chunks = [{"choices": [{"delta": {"reasoning_content": "先想一想"}}]},
                  {"choices": [{"delta": {"reasoning_content": "越剧起源于嵊州"}}]},
                  {"choices": [{"delta": {"content": "## 解析\n考点"}}]},
                  {"choices": [{"delta": {"content": "\n## 参考答案\nA"}}]}]

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_POST(self):
                self.rfile.read(int(self.headers.get("Content-Length") or 0))
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.end_headers()
                for c in chunks:
                    self.wfile.write(("data: " + json.dumps(c, ensure_ascii=False) + "\n\n").encode("utf-8"))
                self.wfile.write(b"data: [DONE]\n\n")

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            seen = []
            text = "".join(localai.stream_chat(f"http://127.0.0.1:{server.server_address[1]}", [],
                                               localai.AiSettings(), on_reasoning=seen.append))
        finally:
            server.shutdown()
        self.assertEqual(text, "## 解析\n考点\n## 参考答案\nA")
        self.assertEqual(seen, [4, 11])


if __name__ == "__main__":
    unittest.main()
