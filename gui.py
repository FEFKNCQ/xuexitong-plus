# -*- coding: utf-8 -*-
"""Modern desktop front end for the Chaoxing study task runner."""

from __future__ import annotations

import configparser
import html
import json
import os
import sys
from pathlib import Path

from PySide6.QtCore import QObject, QProcess, QProcessEnvironment, QTimer, Qt, QUrl, Signal
from PySide6.QtGui import QDesktopServices, QFont, QIcon
from PySide6.QtQuickWidgets import QQuickWidget
from PySide6.QtWebView import QtWebView
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QComboBox,
    QDialog,
    QFormLayout,
    QFrame,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPlainTextEdit,
    QPushButton,
    QSpinBox,
    QStackedWidget,
    QVBoxLayout,
    QWidget,
)


APP_NAME = "学习通PLUS"
APP_VERSION = "3.1.4"
ROOT_DIR = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
BUNDLE_DIR = Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else Path(__file__).resolve().parent
APP_ICON_PATH = ROOT_DIR / "assets" / "learning_plus.png"

if os.name == "nt":
    DATA_DIR = Path(os.environ.get("APPDATA", Path.home())) / "ChaoxingDesktop"
else:
    DATA_DIR = Path.home() / ".config" / "chaoxing-desktop"
DATA_DIR.mkdir(parents=True, exist_ok=True)
CONFIG_PATH = DATA_DIR / "config.ini"


def load_config() -> configparser.ConfigParser:
    if not CONFIG_PATH.exists():
        template = ROOT_DIR / "config_template.ini"
        if template.exists():
            CONFIG_PATH.write_bytes(template.read_bytes())

    config = configparser.ConfigParser(interpolation=None)
    config.read(CONFIG_PATH, encoding="utf-8")
    for section in ("common", "tiku", "notification"):
        if not config.has_section(section):
            config.add_section(section)

    # Turn the template placeholders into empty form fields.
    for key in ("username", "password", "course_list"):
        if config["common"].get(key, "").strip().lower() == "xxx":
            config["common"][key] = ""
    return config


class PreviewBridge(QObject):
    htmlRequested = Signal(str, str)


class ReadOnlyPreviewWindow(QDialog):
    """Video-only preview. The embedded page has no controls and ignores input."""

    BASE_URL = "https://mooc1.chaoxing.com/ananas/modules/video/index.html?v=2025-0725-1842"

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle("学习通 · 只读视频预览")
        self.setWindowIcon(QIcon(str(APP_ICON_PATH)))
        self.setMinimumSize(760, 560)
        self.resize(900, 660)
        self.bridge = PreviewBridge(self)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(22, 20, 22, 20)
        layout.setSpacing(12)
        header = QHBoxLayout()
        title_box = QVBoxLayout()
        title = QLabel("视频预览")
        title.setStyleSheet("font-size: 19pt; font-weight: 700;")
        title_box.addWidget(title)
        self.activity_label = QLabel("等待学习通视频任务")
        self.activity_label.setObjectName("Muted")
        title_box.addWidget(self.activity_label)
        header.addLayout(title_box)
        header.addStretch(1)
        self.read_only_badge = QLabel("只读 · 无控制项")
        self.read_only_badge.setObjectName("PlatformBadge")
        header.addWidget(self.read_only_badge, alignment=Qt.AlignmentFlag.AlignTop)
        layout.addLayout(header)

        self.video_view = QQuickWidget(self)
        self.video_view.setResizeMode(QQuickWidget.ResizeMode.SizeRootObjectToView)
        self.video_view.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.video_view.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents, True)
        self.video_view.rootContext().setContextProperty("previewBridge", self.bridge)
        embedded_qml_dir = ROOT_DIR / "PySide6" / "qml"
        if embedded_qml_dir.exists():
            self.video_view.engine().addImportPath(str(embedded_qml_dir))
        self.video_view.setSource(QUrl.fromLocalFile(str(ROOT_DIR / "preview.qml")))
        layout.addWidget(self.video_view, 1)

        note = QLabel("预览画面为静音，只用于观看当前任务视频；播放、进度、右键菜单和键盘操作均已隐藏或禁用。")
        note.setObjectName("Muted")
        note.setWordWrap(True)
        layout.addWidget(note)
        self.show_message("等待视频任务开始")

    def show_message(self, message: str) -> None:
        safe_message = html.escape(message)
        markup = f"""<!doctype html><html><head><meta charset="utf-8"><style>
            html,body{{height:100%;margin:0;background:#111827;color:#d7e0ee;font-family:'Segoe UI','Microsoft YaHei UI',sans-serif}}
            body{{display:flex;align-items:center;justify-content:center;text-align:center}}
            .box{{padding:32px}} .title{{font-size:22px;font-weight:600}} .sub{{margin-top:10px;color:#99a8bf;font-size:14px}}
            </style></head><body><div class="box"><div class="title">{safe_message}</div>
            <div class="sub">运行学习通视频任务后，画面会自动显示</div></div></body></html>"""
        self.bridge.htmlRequested.emit(markup, self.BASE_URL)

    def set_video_source(self, source: str, title: str) -> None:
        safe_source = html.escape(source, quote=True)
        safe_title = html.escape(title)
        markup = f"""<!doctype html><html><head><meta charset="utf-8"><meta name="referrer" content="unsafe-url">
            <style>html,body{{width:100%;height:100%;margin:0;background:#080d16;overflow:hidden}}
            body{{pointer-events:none;user-select:none}}
            video{{position:fixed;inset:0;width:100%;height:100%;object-fit:contain;background:#080d16;pointer-events:none}}
            </style></head><body><video id="preview" autoplay muted playsinline disablepictureinpicture
            disableremoteplayback controlslist="nodownload noplaybackrate nofullscreen">
            <source src="{safe_source}"></video><script>
            const player=document.getElementById('preview'); player.muted=true;
            player.addEventListener('canplay',()=>player.play().catch(()=>{{}}),{{once:true}});
            player.addEventListener('loadeddata',()=>player.play().catch(()=>{{}}),{{once:true}});
            document.addEventListener('contextmenu',e=>e.preventDefault());
            document.addEventListener('keydown',e=>{{e.preventDefault();e.stopPropagation();}},true);
            </script></body></html>"""
        self.activity_label.setText(title or "学习通视频")
        self.bridge.htmlRequested.emit(markup, self.BASE_URL)

    def stop_video(self) -> None:
        self.show_message("视频任务已结束")

    def closeEvent(self, event) -> None:
        self.show_message("预览窗口已关闭")
        event.accept()


class ChaoxingDesktop(QMainWindow):
    COLORS = {
        "background": "#F3F6FB",
        "sidebar": "#FFFFFF",
        "surface": "#FFFFFF",
        "surface_alt": "#F6F8FC",
        "border": "#E2E8F1",
        "text": "#17243A",
        "muted": "#738198",
        "accent": "#356DF3",
        "blue": "#4D82F5",
        "danger": "#D94D61",
        "success": "#178A68",
    }

    def __init__(self) -> None:
        super().__init__()
        self.config = load_config()
        self.process: QProcess | None = None
        self.preview_window: ReadOnlyPreviewWindow | None = None
        self.preview_source = ""
        self.preview_title = ""
        self.setWindowTitle(APP_NAME)
        self.setWindowIcon(QIcon(str(APP_ICON_PATH)))
        self.setMinimumSize(1000, 720)
        self.resize(1220, 820)
        self.setStyleSheet(self._stylesheet())
        self._build_ui()
        self.preview_window = ReadOnlyPreviewWindow(self)
        self._load_values()

    def _stylesheet(self) -> str:
        c = self.COLORS
        return f"""
            QWidget {{ background: {c['background']}; color: {c['text']}; font-family: 'Microsoft YaHei UI', 'Segoe UI'; font-size: 10pt; }}
            QFrame#Sidebar {{ background: {c['sidebar']}; border: none; border-right: 1px solid {c['border']}; }}
            QFrame#Card {{ background: {c['surface']}; border: 1px solid {c['border']}; border-radius: 16px; }}
            QFrame#Inset {{ background: {c['surface_alt']}; border: 1px solid #E9EEF5; border-radius: 12px; }}
            QLabel#Brand {{ font-size: 16pt; font-weight: 700; }}
            QLabel#BrandHint, QLabel#Muted {{ color: {c['muted']}; font-size: 9pt; }}
            QLabel#PageTitle {{ font-size: 22pt; font-weight: 700; }}
            QLabel#CardTitle {{ font-size: 12pt; font-weight: 700; }}
            QLabel#Status {{ background: #E8F6F1; color: {c['success']}; border-radius: 13px; padding: 7px 13px; font-weight: 650; }}
            QLabel#Status[running="true"] {{ background: #FFF4DF; color: #A76800; }}
            QLabel#Status[error="true"] {{ background: #FCEBED; color: {c['danger']}; }}
            QLabel#Logo {{ background: {c['accent']}; color: #FFFFFF; border-radius: 14px; font-weight: 800; font-size: 13pt; }}
            QLabel#PlatformBadge {{ background: #EDF3FF; color: {c['accent']}; border-radius: 10px; padding: 6px 10px; font-weight: 650; }}
            QLineEdit, QComboBox, QSpinBox {{ background: {c['surface']}; border: 1px solid {c['border']}; border-radius: 9px; padding: 9px 10px; selection-background-color: {c['accent']}; min-height: 22px; }}
            QLineEdit:focus, QComboBox:focus, QSpinBox:focus {{ border-color: {c['accent']}; }}
            QLineEdit:disabled {{ color: #9AA5B5; background: #F2F4F7; }}
            QComboBox QAbstractItemView {{ background: {c['surface']}; color: {c['text']}; selection-background-color: #E9F0FF; border: 1px solid {c['border']}; }}
            QCheckBox {{ spacing: 9px; }}
            QCheckBox::indicator {{ width: 17px; height: 17px; border: 1px solid #B8C3D2; border-radius: 5px; background: {c['surface']}; }}
            QCheckBox::indicator:checked {{ background: {c['accent']}; border-color: {c['accent']}; }}
            QPushButton {{ background: {c['surface']}; color: {c['text']}; border: 1px solid {c['border']}; border-radius: 9px; padding: 9px 13px; }}
            QPushButton:hover {{ background: #F0F4FB; }}
            QPushButton:disabled {{ color: #A2ACBB; background: #F3F5F8; }}
            QPushButton#Primary {{ background: {c['accent']}; color: #FFFFFF; border: none; padding: 11px 19px; font-weight: 700; }}
            QPushButton#Primary:hover {{ background: #275FDB; }}
            QPushButton#Danger {{ color: #A93348; background: #FFF5F6; border-color: #F0C9D0; }}
            QPushButton#Danger:hover {{ background: #FDEBED; }}
            QPushButton#Nav {{ text-align: left; background: transparent; border: none; color: {c['muted']}; padding: 12px 13px; }}
            QPushButton#Nav:hover {{ background: #F5F7FB; }}
            QPushButton#Nav:checked {{ background: #EDF3FF; color: {c['accent']}; font-weight: 700; }}
            QPlainTextEdit {{ background: #F7F9FC; color: #304058; border: 1px solid #E9EEF5; border-radius: 11px; padding: 10px; font-family: 'Cascadia Mono', 'Consolas'; font-size: 9pt; }}
            QScrollBar:vertical {{ background: transparent; width: 9px; margin: 4px; }}
            QScrollBar::handle:vertical {{ background: #C6D0DF; min-height: 25px; border-radius: 4px; }}
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{ height: 0; }}
            QToolTip {{ background: #1B2940; color: {c['text']}; border: 1px solid {c['border']}; padding: 5px; }}
        """

    def _build_ui(self) -> None:
        central = QWidget()
        self.setCentralWidget(central)
        root = QHBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        sidebar = self._frame("Sidebar")
        sidebar.setFixedWidth(220)
        side = QVBoxLayout(sidebar)
        side.setContentsMargins(20, 24, 18, 20)
        side.setSpacing(7)
        logo = self._label("CX", "Logo")
        logo.setAlignment(Qt.AlignmentFlag.AlignCenter)
        logo.setFixedSize(52, 52)
        side.addWidget(logo)
        side.addSpacing(8)
        side.addWidget(self._label(APP_NAME, "Brand"))
        side.addWidget(self._label("学习通课程管理", "BrandHint"))
        side.addSpacing(32)

        self.pages = QStackedWidget()
        self.run_tab = QWidget()
        self.settings_tab = QWidget()
        self.pages.addWidget(self.run_tab)
        self.pages.addWidget(self.settings_tab)
        self.nav_run = self._button("运行面板", "Nav")
        self.nav_run.setCheckable(True)
        self.nav_run.setChecked(True)
        self.nav_settings = self._button("课程选项", "Nav")
        self.nav_settings.setCheckable(True)
        self.nav_run.clicked.connect(lambda: self.pages.setCurrentIndex(0))
        self.nav_settings.clicked.connect(lambda: self.pages.setCurrentIndex(1))
        self.pages.currentChanged.connect(self._sync_navigation)
        side.addWidget(self.nav_run)
        side.addWidget(self.nav_settings)
        side.addStretch(1)

        note = self._frame("Inset")
        note_layout = QVBoxLayout(note)
        note_layout.setContentsMargins(13, 12, 13, 12)
        note_layout.addWidget(QLabel("单平台"))
        note_layout.addWidget(self._label("此界面仅管理学习通课程；账号配置保存在当前 Windows 用户目录。", "BrandHint", word_wrap=True))
        side.addWidget(note)
        side.addSpacing(12)
        side.addWidget(self._label(f"CHAoxing  ·  v{APP_VERSION}", "BrandHint"))
        root.addWidget(sidebar)

        content = QWidget()
        content_layout = QVBoxLayout(content)
        content_layout.setContentsMargins(32, 26, 32, 22)
        content_layout.setSpacing(18)
        header = QHBoxLayout()
        title_box = QVBoxLayout()
        title_box.setSpacing(2)
        self.page_title = self._label("学习通课程", "PageTitle")
        self.page_subtitle = self._label("账号、课程与运行状态", "Muted")
        title_box.addWidget(self.page_title)
        title_box.addWidget(self.page_subtitle)
        header.addLayout(title_box)
        header.addStretch(1)
        self.preview_button = QPushButton("只读视频预览")
        self.preview_button.clicked.connect(self.open_preview)
        header.addWidget(self.preview_button)
        self.status_label = self._label("就绪", "Status")
        header.addWidget(self.status_label, alignment=Qt.AlignmentFlag.AlignTop)
        content_layout.addLayout(header)
        content_layout.addWidget(self.pages, 1)
        content_layout.addWidget(self._build_footer())
        root.addWidget(content, 1)

        self._build_run_tab()
        self._build_settings_tab()

    def _card(self, title: str, description: str) -> tuple[QFrame, QVBoxLayout]:
        card = self._frame("Card")
        layout = QVBoxLayout(card)
        layout.setContentsMargins(18, 15, 18, 17)
        layout.setSpacing(9)
        layout.addWidget(self._label(title, "CardTitle"))
        layout.addWidget(self._label(description, "Muted", word_wrap=True))
        return card, layout

    @staticmethod
    def _frame(object_name: str) -> QFrame:
        frame = QFrame()
        frame.setObjectName(object_name)
        return frame

    @staticmethod
    def _label(text: str, object_name: str | None = None, word_wrap: bool = False) -> QLabel:
        label = QLabel(text)
        if object_name:
            label.setObjectName(object_name)
        label.setWordWrap(word_wrap)
        return label

    @staticmethod
    def _button(text: str, object_name: str | None = None) -> QPushButton:
        button = QPushButton(text)
        if object_name:
            button.setObjectName(object_name)
        return button

    def _build_run_tab(self) -> None:
        layout = QVBoxLayout(self.run_tab)
        layout.setContentsMargins(0, 4, 0, 0)
        layout.setSpacing(14)
        top_row = QHBoxLayout()
        top_row.setSpacing(14)

        account_card, account_layout = self._card("账号与课程", "仅连接学习通。账号信息只保存在本机配置目录。")
        account_form = QFormLayout()
        account_form.setHorizontalSpacing(18)
        account_form.setVerticalSpacing(10)
        self.username_input = QLineEdit()
        self.username_input.setPlaceholderText("手机号或学习通账号")
        self.password_input = QLineEdit()
        self.password_input.setPlaceholderText("密码")
        self.password_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.course_input = QLineEdit()
        self.course_input.setPlaceholderText("留空则启动后选择课程；多个 ID 用英文逗号分隔")
        account_form.addRow("账号", self.username_input)
        account_form.addRow("密码", self.password_input)
        account_layout.addLayout(account_form)
        account_layout.addWidget(self._label("课程 ID（可选）", "Muted"))
        account_layout.addWidget(self.course_input)
        self.cookies_check = QCheckBox("使用本地 cookies 登录")
        self.cookies_check.setToolTip("将 cookies.txt 放在配置目录中；勾选后账号密码不参与登录。")
        self.cookies_check.toggled.connect(self._sync_login_fields)
        account_layout.addWidget(self.cookies_check)
        top_row.addWidget(account_card, 6)

        runtime_card, runtime_layout = self._card("播放与并行", "按课程和网络情况调整任务参数。")
        runtime_form = QFormLayout()
        runtime_form.setHorizontalSpacing(18)
        runtime_form.setVerticalSpacing(10)
        self.speed_combo = QComboBox()
        for value, label in (("1", "标准 · 1×"), ("1.25", "1.25×"), ("1.5", "1.5×"), ("1.75", "1.75×"), ("2", "2×")):
            self.speed_combo.addItem(label, value)
        self.jobs_spin = QSpinBox()
        self.jobs_spin.setRange(1, 8)
        runtime_form.addRow("视频速度", self.speed_combo)
        runtime_form.addRow("并行章节数", self.jobs_spin)
        runtime_layout.addLayout(runtime_form)
        runtime_layout.addStretch(1)
        runtime_layout.addWidget(self._label("章节并行数越高，对网络和设备的占用也越高。", "Muted", word_wrap=True))
        top_row.addWidget(runtime_card, 5)
        layout.addLayout(top_row)

        log_card, log_layout = self._card("运行日志", "学习通课程与任务状态会实时显示在这里。")
        log_header = QHBoxLayout()
        log_header.addStretch(1)
        clear_button = QPushButton("清空日志")
        clear_button.clicked.connect(self._clear_log)
        log_header.addWidget(clear_button)
        log_layout.addLayout(log_header)
        self.log_view = QPlainTextEdit()
        self.log_view.setReadOnly(True)
        self.log_view.setPlaceholderText("准备就绪。保存设置后点击“开始运行”。")
        self.log_view.setMaximumBlockCount(1200)
        log_layout.addWidget(self.log_view, 1)
        layout.addWidget(log_card, 1)

    def _build_settings_tab(self) -> None:
        layout = QVBoxLayout(self.settings_tab)
        layout.setContentsMargins(0, 4, 0, 0)
        layout.setSpacing(14)

        task_card, task_layout = self._card("未开放章节", "选择学习通暂未开放章节的处理方式。")
        task_form = QFormLayout()
        task_form.setHorizontalSpacing(18)
        task_form.setVerticalSpacing(10)
        self.notopen_combo = QComboBox()
        self.notopen_combo.addItem("等待后重试", "retry")
        self.notopen_combo.addItem("跳过该章节", "continue")
        task_form.addRow("处理方式", self.notopen_combo)
        task_layout.addLayout(task_form)
        task_layout.addWidget(self._label("等待重试适合前置章节尚未完成的课程；跳过会继续后续章节。", "Muted", word_wrap=True))
        layout.addWidget(task_card)

        extra_card, extra_layout = self._card("高级选项", "一般情况下保持默认即可。")
        self.learning_count_check = QCheckBox("完成课程后增加章节学习次数")
        self.target_count_spin = QSpinBox()
        self.target_count_spin.setRange(1, 10000)
        extra_layout.addWidget(self.learning_count_check)
        extra_form = QFormLayout()
        extra_form.setHorizontalSpacing(18)
        extra_form.addRow("目标总次数", self.target_count_spin)
        extra_layout.addLayout(extra_form)
        self.learning_count_check.toggled.connect(self._sync_learning_count)
        layout.addWidget(extra_card)
        layout.addStretch(1)

    def _build_footer(self) -> QWidget:
        footer = QWidget()
        layout = QHBoxLayout(footer)
        layout.setContentsMargins(0, 2, 0, 0)
        layout.addWidget(self._label("所有设置保存在本机。", "Muted"))
        layout.addStretch(1)
        self.open_dir_button = QPushButton("打开配置目录")
        self.open_dir_button.clicked.connect(self.open_data_dir)
        layout.addWidget(self.open_dir_button)
        self.save_button = QPushButton("保存配置")
        self.save_button.clicked.connect(self.save_config)
        layout.addWidget(self.save_button)
        self.stop_button = self._button("停止任务", "Danger")
        self.stop_button.setEnabled(False)
        self.stop_button.clicked.connect(self.stop_run)
        layout.addWidget(self.stop_button)
        self.start_button = self._button("开始运行", "Primary")
        self.start_button.clicked.connect(self.start_run)
        layout.addWidget(self.start_button)
        return footer

    def _load_values(self) -> None:
        common = self.config["common"]
        self.username_input.setText(common.get("username", ""))
        self.password_input.setText(common.get("password", ""))
        self.course_input.setText(common.get("course_list", ""))
        try:
            speed = str(float(common.get("speed", "1")))
        except (TypeError, ValueError):
            speed = "1.0"
        index = self.speed_combo.findData(speed)
        if index < 0 and speed.endswith(".0"):
            index = self.speed_combo.findData(speed[:-2])
        self.speed_combo.setCurrentIndex(index if index >= 0 else 0)
        self.jobs_spin.setValue(min(8, max(1, common.getint("jobs", fallback=4))))
        action = common.get("notopen_action", "retry")
        action_index = self.notopen_combo.findData(action)
        self.notopen_combo.setCurrentIndex(action_index if action_index >= 0 else 0)
        self.cookies_check.setChecked(common.getboolean("use_cookies", fallback=False))
        self.learning_count_check.setChecked(common.getboolean("add_learning_count", fallback=False))
        self.target_count_spin.setValue(max(1, common.getint("target_count", fallback=100)))
        self._sync_login_fields(self.cookies_check.isChecked())
        self._sync_learning_count(self.learning_count_check.isChecked())

    def _sync_navigation(self, index: int) -> None:
        self.nav_run.setChecked(index == 0)
        self.nav_settings.setChecked(index == 1)
        if index == 0:
            self.page_title.setText("学习通课程")
            self.page_subtitle.setText("账号、课程与运行状态")
        else:
            self.page_title.setText("课程选项")
            self.page_subtitle.setText("调整学习通章节处理方式")

    def _sync_login_fields(self, use_cookies: bool) -> None:
        self.username_input.setEnabled(not use_cookies)
        self.password_input.setEnabled(not use_cookies)

    def _sync_learning_count(self, enabled: bool) -> None:
        self.target_count_spin.setEnabled(enabled)

    def save_config(self) -> bool:
        common = self.config["common"]
        common["username"] = self.username_input.text().strip()
        common["password"] = self.password_input.text()
        common["course_list"] = self.course_input.text().strip()
        common["speed"] = str(self.speed_combo.currentData() or "1")
        common["jobs"] = str(self.jobs_spin.value())
        common["notopen_action"] = str(self.notopen_combo.currentData() or "retry")
        common["use_cookies"] = str(self.cookies_check.isChecked()).lower()
        common["add_learning_count"] = str(self.learning_count_check.isChecked()).lower()
        common["target_count"] = str(self.target_count_spin.value())

        try:
            with CONFIG_PATH.open("w", encoding="utf-8") as config_file:
                self.config.write(config_file)
        except OSError as exc:
            QMessageBox.critical(self, "保存失败", str(exc))
            return False
        self._append_log(f"配置已保存：{CONFIG_PATH}")
        return True

    def start_run(self) -> None:
        if self.process and self.process.state() != QProcess.ProcessState.NotRunning:
            return
        if not self.cookies_check.isChecked() and (not self.username_input.text().strip() or not self.password_input.text()):
            QMessageBox.warning(self, "需要登录信息", "请填写账号和密码，或选择使用本地 cookies 登录。")
            return
        if not self.save_config():
            return

        process = QProcess(self)
        process.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        process.readyReadStandardOutput.connect(self._read_process_output)
        process.finished.connect(self._on_process_finished)
        process.errorOccurred.connect(self._on_process_error)

        if getattr(sys, "frozen", False):
            program = BUNDLE_DIR / "chaoxing-worker.exe"
            arguments = ["--worker", str(CONFIG_PATH), str(DATA_DIR)]
            if not program.exists():
                QMessageBox.critical(self, "缺少运行组件", f"找不到任务运行组件：\n{program}")
                return
        else:
            program = Path(sys.executable)
            arguments = [str(BUNDLE_DIR / "worker.py"), "--worker", str(CONFIG_PATH), str(DATA_DIR)]

        process.setWorkingDirectory(str(DATA_DIR))
        environment = QProcessEnvironment.systemEnvironment()
        environment.insert("PYTHONUTF8", "1")
        environment.insert("CHAOXING_DESKTOP_PREVIEW", "1")
        process.setProcessEnvironment(environment)
        process.start(str(program), arguments)
        if not process.waitForStarted(2500):
            QMessageBox.critical(self, "启动失败", process.errorString())
            return

        self.process = process
        self.start_button.setEnabled(False)
        self.stop_button.setEnabled(True)
        self._set_status("正在运行", "running")
        self._append_log("任务进程已启动。")

    def _read_process_output(self, final: bool = False) -> None:
        if not self.process:
            return
        output = bytes(self.process.readAllStandardOutput()).decode("utf-8", errors="replace")
        pending = getattr(self, "_output_buffer", "") + output
        lines = pending.replace("\r", "\n").split("\n")
        self._output_buffer = "" if final else lines.pop()
        if final and lines[-1:]:
            lines[-1] = lines[-1] + self._output_buffer
        for line in lines:
            line = line.strip()
            if not line:
                continue
            if line.startswith("__CX_VIDEO_PREVIEW__"):
                try:
                    event = json.loads(line.removeprefix("__CX_VIDEO_PREVIEW__"))
                except (TypeError, ValueError):
                    self.preview_window.show_message("无法读取当前视频预览")
                    continue
                self.preview_source = str(event.get("source", ""))
                self.preview_title = str(event.get("title", "学习通视频"))
                if self.preview_window.isVisible():
                    if self.preview_source:
                        self.preview_window.set_video_source(self.preview_source, self.preview_title)
                    else:
                        self.preview_window.show_message("当前章节没有可显示的视频流")
                continue
            self._append_log(line)

    def _on_process_finished(self, exit_code: int, _exit_status: QProcess.ExitStatus) -> None:
        self._read_process_output(final=True)
        self.start_button.setEnabled(True)
        self.stop_button.setEnabled(False)
        self._set_status("已完成" if exit_code == 0 else "已退出", "idle" if exit_code == 0 else "error")
        self._append_log(f"任务进程结束，退出码：{exit_code}")
        self.preview_source = ""
        self.preview_title = ""
        self.preview_window.stop_video()
        self.process = None

    def _on_process_error(self, _error: QProcess.ProcessError) -> None:
        if self.process and self.process.error() != QProcess.ProcessError.Crashed:
            self._set_status("运行错误", "error")
            self._append_log(f"任务进程错误：{self.process.errorString()}")

    def stop_run(self) -> None:
        if not self.process or self.process.state() == QProcess.ProcessState.NotRunning:
            return
        answer = QMessageBox.question(self, "停止任务", "立即结束当前任务进程？未完成的章节可在下次启动时重试。")
        if answer != QMessageBox.StandardButton.Yes:
            return
        self.process.terminate()
        QTimer.singleShot(1800, self._kill_if_running)
        self._append_log("已发送停止请求。")

    def _kill_if_running(self) -> None:
        if self.process and self.process.state() != QProcess.ProcessState.NotRunning:
            self.process.kill()

    def _set_status(self, value: str, kind: str = "idle") -> None:
        self.status_label.setText(value)
        self.status_label.setProperty("running", "true" if kind == "running" else "false")
        self.status_label.setProperty("error", "true" if kind == "error" else "false")
        self.status_label.style().unpolish(self.status_label)
        self.status_label.style().polish(self.status_label)

    def _append_log(self, message: str) -> None:
        self.log_view.appendPlainText(message)
        for marker in ("开始学习课程:", "当前章节:", "开始任务:", "任务完成:"):
            if marker in message and self.preview_window:
                self.preview_window.activity_label.setText(message.split(marker, 1)[1].strip())
                break

    def _clear_log(self) -> None:
        self.log_view.clear()

    def open_data_dir(self) -> None:
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(DATA_DIR)))

    def open_preview(self) -> None:
        if self.preview_source:
            self.preview_window.set_video_source(self.preview_source, self.preview_title)
        else:
            self.preview_window.show_message("当前没有可预览的视频")
        self.preview_window.show()
        self.preview_window.raise_()
        self.preview_window.activateWindow()

    def closeEvent(self, event) -> None:
        if self.process and self.process.state() != QProcess.ProcessState.NotRunning:
            answer = QMessageBox.question(self, "任务仍在运行", "关闭窗口将结束当前任务。仍要退出吗？")
            if answer != QMessageBox.StandardButton.Yes:
                event.ignore()
                return
            self.process.kill()
        event.accept()


def main() -> None:
    QApplication.setApplicationName(APP_NAME)
    QApplication.setOrganizationName("ChaoxingDesktop")
    os.environ["QT_WEBVIEW_PLUGIN"] = "native"
    app = QApplication(sys.argv)
    QtWebView.initialize()
    app.setWindowIcon(QIcon(str(APP_ICON_PATH)))
    app.setFont(QFont("Segoe UI", 9))
    window = ChaoxingDesktop()
    window.show()
    raise SystemExit(app.exec())


if __name__ == "__main__":
    main()
