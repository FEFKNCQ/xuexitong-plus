# Claude 项目交接说明

## 产品范围

- 产品名：学习通PLUS，Windows 桌面应用。
- 当前目标平台只有超星学习通。后续开发保持单平台，不加入其他网课平台入口。
- 保留现代化界面、课程运行选项和独立的只读视频预览窗。预览窗静音、不可操作。
- Windows 用户数据路径 `%APPDATA%\ChaoxingDesktop` 是为兼容已有配置而保留的，修改前先确认迁移影响。

## 代码结构

- `gui.py`：PySide6 主界面、配置表单、任务进程管理和日志显示。
- `worker.py`：桌面版子进程入口，负责切换到用户数据目录后调用 `main.py`。
- `main.py`：原命令行任务入口；桌面子进程通过它运行现有任务处理逻辑。
- `api/base.py`：学习通课程与任务处理，包括视频状态读取和进度上报。
- `preview.qml`：嵌入式 Qt WebView。只渲染传入的预览页面。
- `build_windows.ps1`：准备便携 Python、安装依赖、分别构建 worker 和 GUI，并生成发行 zip。
- `README_DESKTOP.md`：桌面版安装和使用说明。
- `assets/chaoxing_official.jpg`：学习通官方 App Store 图标原图。
- `assets/render_icon.py`：在原图左上方加 PLUS 字样，生成程序窗口用 PNG 和 exe 用 ICO。

## 视频预览数据流

GUI 启动 worker 时设置 `CHAOXING_DESKTOP_PREVIEW=1`。`api/base.py` 获取视频状态后，通过标准输出发送 `__CX_VIDEO_PREVIEW__` JSON 行；`gui.py` 解析后把地址传给 QML WebView。预览窗口不记录 URL 到普通日志。Windows 构建使用 Qt WebView 的 native/WebView2 后端，运行机器需要 WebView2 Runtime。

预览地址必须来自学习通视频状态响应并通过现有域名检查。真实课程画面尚未用用户账号验证，若调整该流程，需要分别检查无可用地址、加载失败和任务结束时的窗口状态。

## 构建

在 Windows x64 PowerShell 中执行：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\build_windows.ps1
```

构建会联网准备便携 Python 和 Python 依赖。结果位于 `dist\学习通PLUS`，压缩包为 `dist\学习通PLUS-Windows.zip`。发行目录中的 `学习通PLUS.exe`、`chaoxing-worker.exe` 和 `_internal` 必须一起保留。

依赖清单：`requirements-desktop.txt`、`requirements-build.txt`。现有自动化测试位于 `tests/`。

## 开发注意事项

- 不要把真实账号、密码、cookies、个人 `config.ini` 或运行日志加入版本控制或交接包。
- 配置模板是 `config_template.ini`；用户配置在 `%APPDATA%\ChaoxingDesktop\config.ini`。
- UI 与 worker 通过进程标准输出通信，新增日志或事件时避免破坏 `__CX_VIDEO_PREVIEW__` 消息解析。
- 修改打包相关内容时，检查 QML 资源、Qt WebView 插件、图标资源和 worker 是否都进入发行目录。
- 变更 API、配置兼容或任务流程前，先保留现有配置键和学习通运行行为；做完变更后运行相关测试并构建桌面包。
