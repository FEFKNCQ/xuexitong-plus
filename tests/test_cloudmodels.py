import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from ui import cloudmodels

MODELS = ["deepseek-chat", "deepseek-reasoner", "Qwen/Qwen2.5-72B-Instruct"]


def serve(key="sk-test", has_models=True):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            if self.path != "/v1/models" or not has_models:
                self.send_error(404)
                return
            if self.headers.get("Authorization") != f"Bearer {key}":
                self.send_error(401)
                return
            body = json.dumps({"object": "list", "data": [{"id": m, "object": "model"} for m in MODELS]}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, f"http://127.0.0.1:{server.server_address[1]}/v1"


class CloudModelsTest(unittest.TestCase):
    def test_identify(self):
        self.assertEqual(cloudmodels.identify("https://api.deepseek.com/v1"), "DeepSeek")
        self.assertEqual(cloudmodels.identify("https://dashscope.aliyuncs.com/compatible-mode/v1"), "通义千问（阿里云百炼）")
        self.assertEqual(cloudmodels.identify("https://ark.cn-beijing.volces.com/api/v3"), "豆包（火山方舟）")
        self.assertEqual(cloudmodels.identify("http://127.0.0.1:9931/v1"), "本机模型服务")
        self.assertEqual(cloudmodels.identify("https://llm.example.com/v1"), "")
        self.assertEqual(cloudmodels.identify("https://evil-deepseek.com.example.org/v1"), "")
        self.assertEqual(cloudmodels.identify(""), "")

    def test_presets_are_recognised_as_themselves(self):
        for provider in cloudmodels.PROVIDERS:
            self.assertEqual(cloudmodels.identify(provider["endpoint"]), provider["name"], provider)

    def test_lists_models_with_the_key(self):
        server, endpoint = serve()
        try:
            self.assertEqual(cloudmodels.list_models(endpoint + "/", "sk-test"), sorted(MODELS, key=str.lower))
            with self.assertRaisesRegex(cloudmodels.ModelListError, "401"):
                cloudmodels.list_models(endpoint, "sk-wrong")
        finally:
            server.shutdown()

    def test_service_without_model_list(self):
        server, endpoint = serve(has_models=False)
        try:
            with self.assertRaisesRegex(cloudmodels.ModelListError, "手动填写"):
                cloudmodels.list_models(endpoint, "sk-test")
        finally:
            server.shutdown()

    def test_input_checks(self):
        with self.assertRaisesRegex(cloudmodels.ModelListError, "http"):
            cloudmodels.list_models("api.deepseek.com/v1", "k")
        with self.assertRaisesRegex(cloudmodels.ModelListError, "API Key"):
            cloudmodels.list_models("https://api.deepseek.com/v1", "")
        with self.assertRaisesRegex(cloudmodels.ModelListError, "连不上"):
            cloudmodels.list_models("http://127.0.0.1:9/v1", "", timeout=2)


if __name__ == "__main__":
    unittest.main()
