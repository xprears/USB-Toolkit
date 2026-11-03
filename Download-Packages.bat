@echo off
:: 强制 CMD 使用简体中文代码页 (GBK)，杜绝控制台乱码
chcp 936 >nul 2>&1
setlocal EnableDelayedExpansion

:: -------------------------------------------------------------
:: Windows U 盘离线装机助手 - 官方软件包高速下载与完整性维护入口
:: 兼容 Windows 7 SP1 / Windows 10 / Windows 11 (x64 / ARM64)
:: -------------------------------------------------------------

pushd "%~dp0"
set "APP_DIR=%~dp0"
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"
if "%APP_DIR:~-1%"==":" set "APP_DIR=%APP_DIR%\"

echo =============================================================
echo   Windows U 盘离线装机助手 - 官方安装包下载与完整性维护
echo =============================================================
echo.
echo 正在检查 PowerShell 运行环境与脚本依赖...

where powershell.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [错误] 当前系统未检测到 powershell.exe，无法启动下载器。
    echo 请确认系统已安装 Windows Management Framework / PowerShell。
    echo.
    pause
    popd
    exit /b 1
)

if not exist "%APP_DIR%\Scripts\Downloader.ps1" (
    echo.
    echo [错误] 未在以下路径找到 Downloader.ps1:
    echo "%APP_DIR%\Scripts\Downloader.ps1"
    echo 请确认仓库完整，Scripts 文件夹存在。
    echo.
    pause
    popd
    exit /b 1
)

:: 调起 PowerShell 下载器（兼容 PS2.0 及更高版本，传递所有批处理参数）
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    "try { & '%APP_DIR%\Scripts\Downloader.ps1' -UsbRoot '%APP_DIR%' %* } catch { Write-Host ''; Write-Host ('[运行异常] ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }; exit $LASTEXITCODE"

set "EXIT_CODE=%errorlevel%"

echo.
if %EXIT_CODE% neq 0 (
    echo [提示] 下载器退出，退出码: %EXIT_CODE%
)
pause
popd
exit /b %EXIT_CODE%