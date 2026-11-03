import tempfile
import unittest
from pathlib import Path
from unittest import mock

from ui import runtime_deps


class InstallWebView2Test(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.work = Path(self.tmp.name)
        self.steps = []

    def tearDown(self):
        self.tmp.cleanup()

    def fake_download(self, url, dest, progress=None, timeout=30):
        self.assertEqual(url, runtime_deps.WEBVIEW2_URL)
        dest.write_bytes(b"MZ")
        if progress:
            progress(1.0)
        return dest

    def run_install(self):
        return runtime_deps.install_webview2(self.work, lambda text, value: self.steps.append((text, value)))

    def test_success(self):
        with mock.patch.object(runtime_deps, "download", self.fake_download), \
                mock.patch.object(runtime_deps, "is_microsoft_signed", return_value=True), \
                mock.patch.object(runtime_deps, "run_webview2_installer", return_value=0) as run, \
                mock.patch.object(runtime_deps, "webview2_version", return_value="156.0.1.2"):
            self.assertEqual(self.run_install(), "")
        run.assert_called_once()
        self.assertEqual(self.steps[-1][1], 1.0)
        self.assertEqual(list(self.work.iterdir()), [])          # bootstrapper removed

    def test_download_failure_is_reported(self):
        with mock.patch.object(runtime_deps, "download", side_effect=OSError("offline")), \
                mock.patch.object(runtime_deps, "run_webview2_installer") as run:
            self.assertIn("下载", self.run_install())
        run.assert_not_called()

    def test_bad_signature_is_not_run(self):
        with mock.patch.object(runtime_deps, "download", self.fake_download), \
                mock.patch.object(runtime_deps, "is_microsoft_signed", return_value=False), \
                mock.patch.object(runtime_deps, "run_webview2_installer") as run:
            self.assertIn("签名", self.run_install())
        run.assert_not_called()
        self.assertEqual(list(self.work.iterdir()), [])

    def test_still_missing_after_install(self):
        with mock.patch.object(runtime_deps, "download", self.fake_download), \
                mock.patch.object(runtime_deps, "is_microsoft_signed", return_value=True), \
                mock.patch.object(runtime_deps, "run_webview2_installer", return_value=5), \
                mock.patch.object(runtime_deps, "webview2_version", return_value=""):
            self.assertIn("返回码 5", self.run_install())


class SignatureTest(unittest.TestCase):
    def test_unsigned_file_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            fake = Path(tmp) / "fake.exe"
            fake.write_bytes(b"MZ not a real program")
            self.assertFalse(runtime_deps.is_microsoft_signed(fake))


if __name__ == "__main__":
    unittest.main()
