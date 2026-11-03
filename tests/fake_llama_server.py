"""Stand-in for llama.cpp's llama-server, for tests (no model, no GPU).

Supports: --version, -m/--host/--port, /health (503 while "loading"), /v1/models,
/v1/chat/completions with stream=true (SSE). Set FAKE_LLAMA_FAIL=1 to answer chat
requests with an error.
"""

import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPLY = "## 解析\n匀速圆周运动中速度方向时刻改变，但速度大小不变。\n## 参考答案\nC. 速率——速率是速度的大小，保持不变。"


def arg(name, default=None):
    if name in sys.argv:
        return sys.argv[sys.argv.index(name) + 1]
    return default


if "--version" in sys.argv:
    print("version: 4321 (abc1234)")
    print("built with fake compiler for test")
    sys.exit(0)

HOST = arg("--host", "127.0.0.1")
PORT = int(arg("--port", "8089"))
MODEL = os.path.basename(arg("-m", "fake-model.gguf"))
READY_AT = time.monotonic() + float(os.environ.get("FAKE_LLAMA_LOAD_SECONDS", "1.0"))


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _json(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            if time.monotonic() < READY_AT:
                return self._json(503, {"error": {"message": "Loading model", "code": 503}})
            return self._json(200, {"status": "ok"})
        if self.path == "/v1/models":
            return self._json(200, {"object": "list", "data": [{"id": MODEL, "object": "model"}]})
        self._json(404, {"error": {"message": "not found"}})

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        request = json.loads(self.rfile.read(length) or b"{}")
        if self.path != "/v1/chat/completions":
            return self._json(404, {"error": {"message": "not found"}})
        if os.environ.get("FAKE_LLAMA_FAIL") == "1":
            return self._json(500, {"error": {"message": "fake inference failure", "code": 500}})
        user = request["messages"][-1]["content"]
        text = "连接正常" if isinstance(user, str) and "连接正常" in user else REPLY
        if isinstance(user, list):
            text = "（已识别图片）\n" + REPLY
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.end_headers()
        for i in range(0, len(text), 6):
            chunk = {"choices": [{"index": 0, "delta": {"content": text[i:i + 6]}}]}
            self.wfile.write(f"data: {json.dumps(chunk, ensure_ascii=False)}\n\n".encode("utf-8"))
            self.wfile.flush()
            time.sleep(0.01)
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()


print(f"main: server is listening on http://{HOST}:{PORT} - starting the main loop", flush=True)
print(f"load_model: loading model '{MODEL}'", flush=True)
ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
