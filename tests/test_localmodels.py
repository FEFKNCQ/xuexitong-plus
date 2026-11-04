import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from ui import localmodels


def serve(payload):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            if self.path != "/v1/models":
                self.send_error(404)
                return
            body = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


class LocalModelsTest(unittest.TestCase):
    def test_detects_openai_and_llama_formats(self):
        openai_style = serve({"object": "list", "data": [{"id": "qwen2.5:7b"}, {"id": "llama3.1:8b"}]})
        llama_style = serve({"models": [{"name": r"D:\llama\model\Ornith-1.5-35B-Q4_K_M.gguf"}],
                             "data": [{"id": r"D:\llama\model\Ornith-1.5-35B-Q4_K_M.gguf"}]})
        not_models = serve({"hello": "world"})
        try:
            ports = [s.server_address[1] for s in (openai_style, llama_style, not_models)]
            found = localmodels.detect(extra_ports=ports, scan_listening=False)
            by_port = {f["port"]: f for f in found}
            self.assertEqual(by_port[ports[0]]["models"], ["qwen2.5:7b", "llama3.1:8b"])
            self.assertEqual(by_port[ports[0]]["endpoint"], f"http://127.0.0.1:{ports[0]}/v1")
            self.assertEqual(by_port[ports[1]]["models"], ["Ornith-1.5-35B-Q4_K_M"])
            self.assertNotIn(ports[2], by_port)
        finally:
            for s in (openai_style, llama_style, not_models):
                s.shutdown()

    def test_closed_port_is_skipped_quickly(self):
        self.assertIsNone(localmodels.probe(9, timeout=0.5))

    def test_helpers(self):
        self.assertEqual(localmodels.display_model("/models/a/Demo-7B.gguf"), "Demo-7B")
        self.assertEqual(localmodels.display_model("deepseek-r1:14b"), "deepseek-r1:14b")
        self.assertEqual(localmodels.port_of("http://127.0.0.1:9931/v1"), 9931)
        self.assertEqual(localmodels.port_of("http://localhost:11434/v1"), 11434)
        self.assertIsNone(localmodels.port_of("https://api.deepseek.com/v1"))


if __name__ == "__main__":
    unittest.main()
