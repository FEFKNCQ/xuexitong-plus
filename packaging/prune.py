# -*- coding: utf-8 -*-
"""What to leave out of the PyInstaller bundles (used by the .spec files).

Paths are matched against the destination name inside the bundle, lower-cased,
with forward slashes. Everything listed here is either never imported by the app
or only needed by Qt modules / features the app does not use.
"""

from __future__ import annotations

# Qt modules the app never loads (DLLs in PySide6/ and their QML plugins).
_UNUSED_QT = (
    "3d", "quick3d", "charts", "datavisualization", "graphs", "location", "positioning",
    "multimedia", "spatialaudio", "pdf", "sensors", "scxml", "statemachine", "remoteobjects",
    "texttospeech", "virtualkeyboard", "quickparticles", "quicktimeline", "shadertools",
    "bluetooth", "nfc", "serialport", "serialbus", "help", "designer", "uitools", "webengine",
    "webchannel", "websockets", "httpserver", "quickeffectmaker", "insighttracker", "labs",
    "quickcontrols2material", "quickcontrols2universal", "quickcontrols2imagine",
    "quickcontrols2windowsstyleimpl", "sql", "test", "concurrent",
    "xml", "dbus", "openglwidgets", "printsupport", "svgwidgets", "quickwidgets",
)

_UNUSED_QML_DIRS = (
    "qt3d", "qtquick3d", "qtcharts", "qtdatavisualization", "qtgraphs", "qtlocation",
    "qtpositioning", "qtmultimedia", "qtsensors", "qtscxml", "qtremoteobjects",
    "qttexttospeech", "qttest", "qtvirtualkeyboard", "qtwebengine", "qtwebchannel",
    "qtwebsockets", "qtspatialaudio", "qtquickeffectmaker", "qtinsighttracker",
    "qt/labs", "qtqml/statemachine", "qtquick/particles", "qtquick/timeline",
    "qtquick/scene2d", "qtquick/scene3d", "qtquick/virtualkeyboard", "qtquick/pdf",
    "qtquick/localstorage", "qtquick/vectorimage",
    "qtquick/controls/material", "qtquick/controls/universal", "qtquick/controls/imagine",
    "qtquick/controls/windows",  # (Fusion stays: FluentWinUI3 is built on it)
)

_UNUSED_PLUGINS = (
    "qmltooling", "multimedia", "position", "sensors", "sqldrivers", "canbus", "texttospeech",
    "geoservices", "renderers", "sceneparsers", "assetimporters", "geometryloaders",
    "renderplugins", "designer", "printsupport", "virtualkeyboard", "scxmldatamodel",
)


def _qt_dll_unused(name: str) -> bool:
    # pyside6/qt6<module>.dll and pyside6/qt<module>.pyd
    base = name.rsplit("/", 1)[-1]
    for prefix in ("qt6", "qt"):
        if base.startswith(prefix) and (base.endswith(".dll") or base.endswith(".pyd")):
            module = base[len(prefix):].split(".")[0]
            return any(module.startswith(u) for u in _UNUSED_QT)
    return False


def is_unused(dest: str, *, keep_dialogs: bool = False, keep_widgets: bool = True) -> bool:
    n = dest.replace("\\", "/").lower()
    if n.endswith(".obj") or "/objects-" in n:
        return True
    if n.startswith("pyside6/"):
        rest = n[len("pyside6/"):]
        if rest == "opengl32sw.dll" or rest.startswith("translations/"):
            return True
        if rest.startswith("qml/"):
            q = rest[len("qml/"):]
            if any(q == d or q.startswith(d + "/") for d in _UNUSED_QML_DIRS):
                return True
            if not keep_dialogs and (q.startswith("qtquick/dialogs") or q.startswith("qtquick/nativestyle")):
                return True
            return False
        if rest.startswith("plugins/"):
            p = rest[len("plugins/"):]
            return any(p.startswith(u + "/") for u in _UNUSED_PLUGINS)
        if "/" not in rest:
            if not keep_dialogs and rest.startswith("qt6quickdialogs"):
                return True
            if not keep_widgets and rest.startswith(("qt6widgets", "qtwidgets")):
                return True
            # Note: QtOpenGL.pyd must stay - PySide6.QtQuick imports it.
            return _qt_dll_unused(rest)
        return False
    # Worker side: ddddocr only ever loads common_old.onnx (DdddOcr() default);
    # OpenCV's ffmpeg video backend and Pillow's AVIF codec are never used.
    if n in ("ddddocr/common.onnx", "ddddocr/common_det.onnx"):
        return True
    if n.startswith("cv2/opencv_videoio_ffmpeg"):
        return True
    if n.startswith("pil/_avif"):
        return True
    return False


def prune(toc, **kwargs):
    """Filter a PyInstaller TOC (list of (dest, src, typecode) tuples)."""
    kept = [entry for entry in toc if not is_unused(entry[0], **kwargs)]
    return kept, len(toc) - len(kept)
