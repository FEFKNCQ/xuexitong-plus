# -*- mode: python ; coding: utf-8 -*-
# Setup program stub (one file). build_windows.ps1 appends the release zip to it.
import sys
from pathlib import Path

ROOT = Path(SPECPATH).resolve().parent
sys.path.insert(0, str(Path(SPECPATH)))
from prune import prune  # noqa: E402

setup = Analysis(
    [str(ROOT / "installer" / "setup.py")],
    pathex=[str(ROOT)],
    datas=[
        (str(ROOT / "ui" / "qml"), "ui/qml"),
        (str(ROOT / "installer" / "qml"), "installer/qml"),
        (str(ROOT / "assets" / "learning_plus.png"), "assets"),
    ],
    # lzma: the appended payload is an LZMA zip (packaging/make_payload.py); zipfile imports it lazily.
    hiddenimports=["PySide6.QtQml", "PySide6.QtQuick", "PySide6.QtQuickControls2", "lzma"],
    excludes=["tkinter", "PySide6.QtWebView", "PySide6.QtWebEngineCore", "PySide6.QtWidgets",
              "numpy", "PIL"],
    noarchive=False,
)
# The installer uses QtQuick.Dialogs (FolderDialog); keep it here.
setup.binaries, dropped_bin = prune(setup.binaries, keep_dialogs=True)
setup.datas, dropped_dat = prune(setup.datas, keep_dialogs=True)
print(f"prune: dropped {dropped_bin} binaries, {dropped_dat} data files")

EXE(
    PYZ(setup.pure),
    setup.scripts,
    setup.binaries,
    setup.datas,
    [],
    name="setup-stub",
    icon=str(ROOT / "assets" / "learning_plus.ico"),
    console=False,
    upx=False,
)
