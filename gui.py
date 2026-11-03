# -*- coding: utf-8 -*-
"""Desktop front end for the Chaoxing study task runner (Qt Quick / QML)."""

from __future__ import annotations

import os
import sys

from PySide6.QtGui import QFont, QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWebView import QtWebView

from ui.startup import APP_NAME, ROOT_DIR, StartupLoader


def main() -> None:
    os.environ["QT_WEBVIEW_PLUGIN"] = "native"
    QGuiApplication.setApplicationName(APP_NAME)
    QGuiApplication.setOrganizationName("ChaoxingDesktop")
    QtWebView.initialize()
    app = QGuiApplication(sys.argv)
    app.setWindowIcon(QIcon(str(ROOT_DIR / "assets" / "learning_plus.png")))
    app.setFont(QFont("Microsoft YaHei UI", 10))

    QQuickStyle.setStyle(os.environ.get("CHAOXING_DESKTOP_STYLE", "FluentWinUI3"))
    QQuickStyle.setFallbackStyle("Basic")

    engine = QQmlApplicationEngine()
    embedded_qml_dir = ROOT_DIR / "PySide6" / "qml"
    if embedded_qml_dir.exists():
        engine.addImportPath(str(embedded_qml_dir))

    # Splash first; config, runtime checks and the main window load behind it.
    startup = StartupLoader(app, engine)
    startup.start()
    exit_code = app.exec()
    if startup.controller is not None:
        startup.controller.shutdown()
    del engine
    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
