# Claude 项目交接说明

## 产品范围

- 产品名：学习通PLUS，Windows 桌面应用。
- 当前目标平台只有超星学习通。后续开发保持单平台，不加入其他网课平台入口。
- 界面为 Qt Quick（QML）+ FluentWinUI3 样式，跟随系统浅色/深色，也可在设置里固定。
- 首页左栏是仪表盘和基本参数，右栏是只读可视化面板（视频 / 答题）。可视化面板静音、不可操作。
- Windows 用户数据路径 `%APPDATA%\ChaoxingDesktop` 是为兼容已有配置而保留的，修改前先确认迁移影响。

## 代码结构

- `gui.py`：入口，创建 QGuiApplication 和 QML 引擎，设置 FluentWinUI3 样式，交给 `ui/startup.py`。
- `ui/startup.py`：`StartupLoader`。先显示 `Splash.qml`，再在后台依次读取配置、检查运行组件、异步编译 `Main.qml`、异步创建主窗口，并把进度报告给启动画面。启动画面要等打字动画结束且加载完成才关闭，然后显示主窗口。
- `ui/qml/Onboarding.qml`：首次启动引导（欢迎 > 免责声明 > 账号 > 开始使用）。免责声明一步要求用户在输入框里完整写一遍声明（忽略空白；声明文字可选中复制，但界面不提示），一致后才能继续。账号一步可以“稍后配置”，之后运行面板顶部会一直显示提醒条，导航“设置”上有闪烁的提醒点，点“开始运行”会直接跳到设置。完成状态存在 QSettings 的 `onboarding/done`；设置页“关于”里可以重新打开。开发时设置 `CHAOXING_DESKTOP_ONBOARDING=1` 可强制显示。
- `ui/qml/AppButton.qml`、`AppCheckBox.qml`、`AppSwitch.qml`、`AppTextField.qml`、`BaseDialog.qml`：自绘控件，外观不依赖 Quick Controls 样式（打包版若样式回退也保持一致）。新增按钮/勾选框/开关/对话框请用这些，不要直接用 `Button` / `CheckBox` / `Switch` / `Dialog`。动画时长统一用 `Theme.fast / normal / slow`。
- `installer/setup.py` + `installer/qml/Setup.qml`：自制安装程序（欢迎 > 许可协议 > 安装选项 > 正在安装 > 完成），复用 `ui/qml` 的控件和 `Theme`。按当前用户安装到 `%LOCALAPPDATA%\Programs\学习通PLUS`，写 `HKCU\...\Uninstall\XueXiTongPlus`，可选桌面和开始菜单快捷方式。发行 zip 直接追加在安装程序 exe 末尾，`zipfile` 从文件尾部找到它；开发时用 `python installer\setup.py --payload dist\XueXiTong-Plus-Windows-<版本>.zip`。`--silent [--dir 路径] [--no-shortcuts]` 静默安装。日志在 `%TEMP%\xxtplus-setup.log`。
- `ui/runtime_deps.py`：外部运行组件。MSVC 运行库已打进包里；唯一需要系统提供的是 Microsoft Edge WebView2 运行时（视频预览）。安装程序在“安装选项”页显示检测结果（读 EdgeUpdate 注册表的 `pv`），缺少时安装过程中从 `go.microsoft.com` 下载 Evergreen 引导程序，用 `Get-AuthenticodeSignature` 确认是有效的 Microsoft 签名后 `/silent /install`（非管理员时按当前用户安装）。失败只在完成页提示，不让安装失败。`--silent` 安装同样会装，`--no-deps` 跳过。
- `ui/winsetup.py`：安装和卸载共用的注册表、快捷方式、进程检查逻辑。安装目录里会写 `.xxtplus-install` 标记文件，卸载只删除带这个标记的目录。
- `ui/uninstall.py` + `ui/qml/Uninstall.qml`：卸载程序就是 `学习通PLUS.exe --uninstall`（`--quiet` 无界面，默认清除账号数据，`--keep-account` 保留）。删除快捷方式和注册表项；“清除账号数据”默认勾选（清空 config.ini 的账号密码、关闭 cookies 登录、删除 cookies.txt），也可删除整个 `%APPDATA%\ChaoxingDesktop` 和 QSettings。退出后由 cmd 延迟删除程序目录。
- `ui/updater.py` + `ui/qml/UpdateDialog.qml`：联网更新。查询 `Kerxs/XueXiTong-Plus` 的 latest release，找文件名含 setup 的 `.exe` 资源，下载到 `%TEMP%\xxtplus-update`，用 GitHub 提供的 `digest`（sha256）校验后启动安装程序并退出。仓库名改了要同步改 `REPO`。只有打包版会在启动时自动检查（`XXTPLUS_UPDATE_CHECK=1` 可在开发时强制）。发布新版本：改 `APP_VERSION` → 构建 → 新建 tag `v<版本>` 的 Release，上传 Setup.exe（和 zip）。发行文件名必须是 ASCII（`XueXiTong-Plus-…`）：GitHub 会删掉资源名里的中文字符。
- `packaging/app.spec` / `packaging/setup.spec` / `packaging/prune.py`：PyInstaller 打包。GUI 和 worker 打进同一个目录，共用一个 `_internal`（worker 不再是单文件，启动任务时不用解压）。`prune.py` 去掉不用的 Qt 模块（3D、Charts、多媒体、其他控件样式、翻译、软件 OpenGL 等）、ddddocr 不加载的两个模型、OpenCV 的 ffmpeg。注意 `PySide6.QtQuick` 依赖 `QtOpenGL.pyd`，不能删。改了裁剪规则后要跑 `tests/test_packaging_and_cleanup.py` 并启动打包版看 `gui.log`。
- 设置页的界面偏好（主题、动画、启动动画、运行结束提醒、自动检查更新、关闭到托盘）都存 QSettings；`Theme.motion` 为 false 时所有 `Theme.fast/normal/slow` 变成 0，循环动画也停止。
- `ui/localai.py` + `ui/assistant.py` + `ui/qml/AssistantPage.qml`：“AI 讲解”页，本地 GGUF 模型（llama.cpp 的 `llama-server`）讲解题目。
  - 边界：输出只在这个页面里给用户看；**不写回任务进程、不进入 `config.ini` 的 `[tiku]`、不参与任何自动作答或提交**。设置存 `%APPDATA%\ChaoxingDesktop\local_ai.json`，审核历史存 `ai_history.json`。不下载模型。
  - 人工审核：每条结果先是“待审核”；只有用户标记“采纳”的结果能复制（`copyAnswer` 会拒绝其他状态）；可写审核备注。
  - 两种模式：本机启动 llama-server（自动检测：设置路径 → PATH → 常见安装目录，运行 `--version`），或连接已运行的 OpenAI 兼容服务。参数：模型 / mmproj 路径、端口、上下文、GPU 层数、线程、温度、最大 token、额外参数。用 `/health` 等待模型加载，`/v1/chat/completions` 流式推理；停止时结束整个进程树。
  - 题目来源：当前章节检测（来自运行面板的预览数据，自动带上识别到的课程和章节）、手动粘贴（自动拆出题干和选项）、图片（需要 mmproj，多模态）。
  - 测试：`tests/test_localai.py` 用 `tests/fake_llama_server.py` 模拟 llama-server，覆盖检测、启动、加载等待、连接测试、流式推理、错误、崩溃退出、审核门槛。
- `ui/advanced.py` + `ui/qml/AdvancedOptions.qml`：设置页“高级选项”，把 config.ini 里基本设置没覆盖的键（题库 provider 及各题库参数、提交与覆盖率、查题间隔、重做、判断题词表、通知推送）做成控件。字段表在 `advanced.GROUPS`，值按 config.ini 的字符串存取，随“保存”一起写回；文件里没有的键只有改过默认值才会写入。新增 worker 读取的配置键时在这里加字段，`tests/test_advanced.py` 会检查 provider 名在 `api/answer.py` / `api/notification.py` 中存在。
- `ui/videoproxy.py`：视频预览的本地代理（只监听 127.0.0.1，只代理已登记的 `*.chaoxing.com` / `*.cldisk.com` 地址；视频 CDN 实际在 `s1/s2.cldisk.com`）。WebView2 的 `loadHtml()` 实际是 data: URL，CDN 收不到学习通的 Referer 会拒绝视频；现在预览页面和视频都由代理提供，代理转发时带上 Referer 并透传 Range。
- `ui/tray.py`：后台模式（系统托盘 + 单实例）。关闭窗口默认隐藏到托盘，任务继续；再次启动程序会唤出已运行的窗口。所有真正退出的路径都走 `Main.qml` 的 `quitApp()`。
- 编码：打包版 worker 不认 `PYTHONUTF8`，`worker.py` 启动时强制 stdout/stderr 为 UTF-8；GUI 用 `StreamDecoder` 增量解码，遇到非 UTF-8 自动改用 GB18030。
- 运行日志和设置界面里不显示本机完整路径（统一写 `%APPDATA%\ChaoxingDesktop`），避免截图泄露用户名。
- `ui/controller.py`：`AppController`，暴露给 QML 的 `controller`。负责 `config.ini` 读写、启动/停止 worker、写 worker 标准输入（课程选择、Y/n 确认）、主题和预览数据。
- `ui/output_parser.py`：把 worker 输出解析成事件（loguru 日志、tqdm 进度、课程列表、输入提示、预览事件）。纯 Python，无 Qt 依赖。
- `ui/models.py`：日志模型（级别过滤、1200 行上限）和任务进度模型。
- `ui/qml/`：界面。`Main.qml` 是窗口和导航，`DashboardPage.qml` / `SettingsPage.qml` 是两个页面，`Theme.qml` 是颜色 token 单例（由 `qmldir` 注册），其余是组件。
- `worker.py`：桌面版子进程入口，负责切换到用户数据目录后调用 `main.py`。
- `main.py`：原命令行任务入口；桌面子进程通过它运行现有任务处理逻辑。
- `api/base.py`：学习通课程与任务处理，包括视频状态读取、进度上报和答题。
- `build_windows.ps1`：准备便携 Python、安装依赖、分别构建 worker 和 GUI，并生成发行 zip。
- `README_DESKTOP.md`：桌面版安装和使用说明。
- `assets/chaoxing_official.jpg`：学习通官方 App Store 图标原图。
- `assets/render_icon.py`：在原图左上方加 PLUS 字样，生成程序窗口用 PNG 和 exe 用 ICO。

## 预览数据流

GUI 启动 worker 时设置 `CHAOXING_DESKTOP_PREVIEW=1`（以及 `PYTHONUNBUFFERED=1`）。`api/base.py` 通过标准输出发送两种事件行，`ui/output_parser.py` 解析，不会进入普通日志：

- `__CX_VIDEO_PREVIEW__{"source","title"}`：获取视频状态后发送。`ui/controller.py` 生成静音、无控件的 HTML，交给 `VideoView.qml` 里的 WebView。Windows 构建使用 Qt WebView 的 native/WebView2 后端，运行机器需要 WebView2 Runtime。WebView2 后端不支持 `loadHtml` 的 base URL（页面按 `about:blank` 处理）。
- `__CX_WORK_PREVIEW__{...}`：`study_work` 填好答案、提交前发送 `phase=filled`（题目、选项、所填答案、来源、覆盖率），提交后发送 `submitted` / `saved` / `failed`。由 `_emit_work_preview` 输出，异常全部吞掉，不影响答题流程。`WorkView.qml` 用 QML 原生绘制，不加载学习通网页。

视频预览地址必须来自学习通视频状态响应并通过现有域名检查。真实课程画面尚未用用户账号验证，若调整该流程，需要分别检查无可用地址、加载失败和任务结束时的面板状态。

原生 WebView 会盖住 QML 弹层，所以对话框打开时 `VideoView` 会被暂停显示（`suspended`）。

WebView2 在创建时就定下可见性：在主窗口还藏在启动画面后面、或 WebView 本身隐藏时创建的，之后即使显示出来，页面的 `document.visibilityState` 仍是 `hidden`，Chromium 不会加载 `<video>`（表现为白屏、代理收不到 `/v/` 请求）。所以 `VideoView` 用 `Loader` 只在真正显示时创建 WebView，每次显示都新建一个；不要改回常驻 WebView + 切换 `visible`。

## worker 标准输入

`main.py` 会在两处调用 `input()`：课程 ID 为空时选择课程、大模型连接检查失败时 Y/n 确认。GUI 识别这两种提示后弹出对话框，再把答案写入 worker 标准输入。新增 `input()` 调用时要同步更新 `ui/output_parser.py`，否则任务会卡住。

## 界面开发测试

非打包模式下，环境变量 `CHAOXING_DESKTOP_FAKE_WORKER=<脚本路径>` 会让 GUI 用指定脚本代替 `worker.py`，便于不登录就测试界面。设置 `APPDATA` 到临时目录可避免改动真实配置。

## 构建

在 Windows x64 PowerShell 中执行：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\build_windows.ps1
```

构建会联网准备便携 Python 和 Python 依赖。结果位于 `dist\学习通PLUS`，压缩包为 `dist\XueXiTong-Plus-Windows-<版本>.zip`，安装程序为 `dist\XueXiTong-Plus-Setup-<版本>.exe`（版本号取自 `ui/controller.py` 的 `APP_VERSION`）。构建会删除 Qt qml 目录里的 `objects-*` 编译残留，它们路径过深，安装时会超过 Windows 路径长度限制。界面的 Qt 日志写在 `%APPDATA%\ChaoxingDesktop\gui.log`，排查打包版问题先看这里。发行目录中的 `学习通PLUS.exe`、`chaoxing-worker.exe` 和 `_internal` 必须一起保留。

依赖清单：`requirements-desktop.txt`、`requirements-build.txt`。现有自动化测试位于 `tests/`。

## 开发注意事项

- 不要把真实账号、密码、cookies、个人 `config.ini` 或运行日志加入版本控制或交接包。
- 配置模板是 `config_template.ini`；用户配置在 `%APPDATA%\ChaoxingDesktop\config.ini`。
- UI 与 worker 通过进程标准输出通信，新增日志或事件时避免破坏 `__CX_VIDEO_PREVIEW__` / `__CX_WORK_PREVIEW__` 消息解析；解析规则的测试在 `tests/test_output_parser.py`。
- 修改打包相关内容时，检查 `ui/qml` 资源、Qt WebView 插件、图标资源和 worker 是否都进入发行目录。
- 界面偏好（主题、窗口尺寸）保存在 QSettings，不写入 `config.ini`。
- 变更 API、配置兼容或任务流程前，先保留现有配置键和学习通运行行为；做完变更后运行相关测试并构建桌面包。
