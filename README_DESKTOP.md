# 学习通PLUS

此桌面界面只提供学习通课程相关入口，不包含其他网课平台切换项。

## 使用

1. 解压 `学习通PLUS-Windows.zip` 的全部内容。
2. 双击 `学习通PLUS.exe`。请保持同目录中的 `chaoxing-worker.exe` 和 `_internal` 文件夹完整。
3. 在界面填写账号、课程和运行选项，点击“保存配置”后运行。
4. 点击“只读视频预览”可打开独立视频窗口。窗口静音播放当前学习通视频，没有播放控件、进度条或交互入口。视频窗口使用 Windows WebView2 运行时。

程序配置、cookies 和日志保存在 `%APPDATA%\ChaoxingDesktop`。点击“打开配置目录”可直接访问。账号密码以明文保存在本机的 `config.ini` 中。

需要使用 cookies 登录时，将 `cookies.txt` 放入该配置目录，并在界面勾选 cookies 登录。

## 从源码构建

在 Windows x64 上运行 PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\build_windows.ps1
```

图标以[学习通官方 App Store 图标](https://apps.apple.com/cn/app/%E5%AD%A6%E4%B9%A0%E9%80%9A/id977946724)为底图，并在左上角添加 PLUS 标识。发行包附带 ICO、PNG 和官方原图。

脚本会在 `.build` 中准备便携 Python 和依赖，构建结果位于 `dist\学习通PLUS`，发行压缩包为 `dist\学习通PLUS-Windows.zip`。
