$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildRoot = Join-Path $projectRoot ".build"
$pythonRoot = Join-Path $buildRoot "python-3.13"
$pythonArchive = Join-Path $buildRoot "python-3.13.17-embed-amd64.zip"
$pipWheel = Join-Path $buildRoot "pip-wheel.whl"
$pipArchive = Join-Path $buildRoot "pip-wheel.zip"
$pythonExe = Join-Path $pythonRoot "python.exe"
$pythonUrl = "https://www.python.org/ftp/python/3.13.17/python-3.13.17-embed-amd64.zip"

New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null

if (-not (Test-Path -LiteralPath $pythonExe)) {
    if (-not (Test-Path -LiteralPath $pythonArchive)) {
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonArchive
    }
    New-Item -ItemType Directory -Path $pythonRoot -Force | Out-Null
    Expand-Archive -LiteralPath $pythonArchive -DestinationPath $pythonRoot -Force
    @("python313.zip", ".", "Lib\site-packages", "import site") |
        Set-Content -LiteralPath (Join-Path $pythonRoot "python313._pth") -Encoding Ascii
    New-Item -ItemType Directory -Path (Join-Path $pythonRoot "Lib\site-packages") -Force | Out-Null
    $pipMetadata = Invoke-RestMethod -Uri "https://pypi.org/pypi/pip/json"
    $pipPackage = $pipMetadata.urls | Where-Object { $_.filename -match '^pip-.*-py3-none-any\.whl$' } | Select-Object -First 1
    if (-not $pipPackage) { throw "Could not find the pip wheel for bootstrapping." }
    Invoke-WebRequest -Uri $pipPackage.url -OutFile $pipWheel
    Copy-Item -LiteralPath $pipWheel -Destination $pipArchive -Force
    Expand-Archive -LiteralPath $pipArchive -DestinationPath (Join-Path $pythonRoot "Lib\site-packages") -Force
}

& $pythonExe -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed." }
& $pythonExe -m pip install setuptools wheel
if ($LASTEXITCODE -ne 0) { throw "Build tooling installation failed." }
& $pythonExe -m pip install --no-build-isolation --cache-dir (Join-Path $buildRoot "pip-cache") `
    -r (Join-Path $projectRoot "requirements-desktop.txt") -r (Join-Path $projectRoot "requirements-build.txt")
if ($LASTEXITCODE -ne 0) { throw "Dependency installation failed." }
& $pythonExe (Join-Path $projectRoot "assets\render_icon.py")
if ($LASTEXITCODE -ne 0) { throw "Application icon generation failed." }

$distRoot = Join-Path $projectRoot "dist"
$workRoot = Join-Path $buildRoot "pyinstaller"
$workerExe = Join-Path $distRoot "chaoxing-worker.exe"
New-Item -ItemType Directory -Path $distRoot -Force | Out-Null

Remove-Item -LiteralPath $workerExe -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
& $pythonExe -m PyInstaller --noconfirm --clean --onefile --console `
    --name chaoxing-worker `
    --add-data "$projectRoot\resource;resource" `
    --hidden-import api.captcha `
    --collect-data ddddocr `
    --distpath $distRoot --workpath $workRoot `
    (Join-Path $projectRoot "worker.py")
if ($LASTEXITCODE -ne 0) { throw "Worker executable build failed." }

$guiWork = Join-Path $buildRoot "pyinstaller-gui"
Remove-Item -LiteralPath (Join-Path $distRoot "Chaoxing") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $distRoot "Chaoxing-Windows.zip") -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $distRoot "Chaoxing-Windows") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $distRoot "学习通PLUS") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $distRoot "学习通PLUS-Windows.zip") -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $guiWork -Recurse -Force -ErrorAction SilentlyContinue
& $pythonExe -m PyInstaller --noconfirm --clean --onedir --windowed `
    --name 学习通PLUS `
    --icon "$projectRoot\assets\learning_plus.ico" `
    --add-data "$projectRoot\config_template.ini;." `
    --add-data "$projectRoot\preview.qml;." `
    --add-data "$projectRoot\assets\learning_plus.png;assets" `
    --add-data "$pythonRoot\Lib\site-packages\PySide6\qml;PySide6\qml" `
    --add-binary "$pythonRoot\Lib\site-packages\PySide6\plugins\webview\qtwebview_webview2.dll;PySide6\plugins\webview" `
    --hidden-import PySide6.QtWebView `
    --hidden-import PySide6.QtQuickWidgets `
    --distpath $distRoot --workpath $guiWork `
    (Join-Path $projectRoot "gui.py")
if ($LASTEXITCODE -ne 0) { throw "GUI executable build failed." }

$releaseDir = Join-Path $distRoot "学习通PLUS"
Copy-Item -LiteralPath $workerExe -Destination (Join-Path $releaseDir "chaoxing-worker.exe") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "README_DESKTOP.md") -Destination (Join-Path $releaseDir "README.txt") -Force
$releaseAssets = Join-Path $releaseDir "assets"
New-Item -ItemType Directory -Path $releaseAssets -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot "assets\learning_plus.ico") -Destination $releaseAssets -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "assets\learning_plus.png") -Destination $releaseAssets -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "assets\chaoxing_official.jpg") -Destination $releaseAssets -Force
$releaseZip = Join-Path $projectRoot "dist\学习通PLUS-Windows.zip"
Compress-Archive -LiteralPath $releaseDir -DestinationPath $releaseZip -CompressionLevel Optimal -Force
Write-Host "Build complete: $(Join-Path $releaseDir '学习通PLUS.exe')"
Write-Host "Worker component: $(Join-Path $releaseDir 'chaoxing-worker.exe')"
Write-Host "Release archive: $releaseZip"
