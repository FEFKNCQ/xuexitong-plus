# -*- coding: utf-8 -*-
"""Stand-in for OpenCV, which the packaged app does not ship (it is ~83 MB).

ddddocr imports cv2 when it is imported, but its text OCR - DdddOcr().classification,
the only feature api/captcha.py uses - works on Pillow images and never calls OpenCV.
Only slider matching, object detection and colour filters need it; using any of them
raises here with a clear message instead of failing at ``import ddddocr``.
"""

__version__ = "0.0.0-stub"


def __getattr__(name):
    raise ImportError(f"OpenCV 未随程序打包（访问 cv2.{name}）；文字验证码识别不需要它")
