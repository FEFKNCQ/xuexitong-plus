import threading
import unittest
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from ui.videoproxy import REFERER, VideoProxy, allowed

VIDEO = bytes(range(256)) * 400  # 100 KB of "video"


class FakeCdn(BaseHTTPRequestHandler):
    """Refuses requests without the chaoxing Referer, supports Range like a real CDN."""

    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.headers.get("Referer") != REFERER:
            self.send_error(403)
            return
        rng = self.headers.get("Range")
        if rng:
            start, _, end = rng.removeprefix("bytes=").partition("-")
            start, end = int(start), int(end) if end else len(VIDEO) - 1
            body = VIDEO[start:end + 1]
            self.send_response(206)
            self.send_header("Content-Range", f"bytes {start}-{end}/{len(VIDEO)}")
        else:
            body = VIDEO
            self.send_response(200)
        self.send_header("Content-Type", "video/mp4")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class VideoProxyTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cdn = ThreadingHTTPServer(("127.0.0.1", 0), FakeCdn)
        threading.Thread(target=cls.cdn.serve_forever, daemon=True).start()
        cls.video_url = f"http://127.0.0.1:{cls.cdn.server_address[1]}/video/abc.mp4?sig=1"
        # The fake CDN is on 127.0.0.1, so allow that host for the test (production: chaoxing.com only).
        cls.proxy = VideoProxy(allowed_hosts=("127.0.0.1",))

    @classmethod
    def tearDownClass(cls):
        cls.proxy.stop()
        cls.cdn.shutdown()

    def test_direct_request_without_referer_is_refused(self):
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(self.video_url, timeout=5)
        self.assertEqual(ctx.exception.code, 403)

    def test_proxy_adds_referer_and_streams(self):
        local = self.proxy.register(self.video_url)
        self.assertTrue(local.startswith("http://127.0.0.1:"))
        with urllib.request.urlopen(local, timeout=5) as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.headers["Content-Type"], "video/mp4")
            self.assertEqual(resp.read(), VIDEO)

    def test_range_passthrough(self):
        local = self.proxy.register(self.video_url)
        req = urllib.request.Request(local, headers={"Range": "bytes=1000-1999"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            self.assertEqual(resp.status, 206)
            self.assertEqual(resp.headers["Content-Range"], f"bytes 1000-1999/{len(VIDEO)}")
            self.assertEqual(resp.read(), VIDEO[1000:2000])

    def test_unknown_token_and_disallowed_host(self):
        self.proxy.start()
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(f"http://127.0.0.1:{self.proxy.port}/v/not-registered", timeout=5)
        self.assertEqual(ctx.exception.code, 404)
        with self.assertRaises(ValueError):
            self.proxy.register("https://example.com/video.mp4")

    def test_allowed(self):
        hosts = ("chaoxing.com",)
        self.assertTrue(allowed("https://s1.ananas.chaoxing.com/x.mp4", hosts))
        self.assertTrue(allowed("http://chaoxing.com/x.mp4", hosts))
        self.assertFalse(allowed("https://evilchaoxing.com/x.mp4", hosts))
        self.assertFalse(allowed("https://chaoxing.com.evil.io/x.mp4", hosts))
        self.assertFalse(allowed("file:///C:/x.mp4", hosts))


if __name__ == "__main__":
    unittest.main()
