@echo off
:: 强制 CMD 使用简体中文代码页 (GBK)，杜绝控制台乱码
chcp 936 >nul 2>&1
setlocal EnableDelayedExpansion

:: -------------------------------------------------------------
:: Windows 离线装机助手 - 原生 ISO 光盘镜像一键打包入口
:: 零依赖：直接利用 Windows 原生 PowerShell 与 IMAPI2 生成标准 ISO
# -------------------------------------------------------------

pushd "%~dp0"
set "APP_DIR=%~dp0"
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"
if "%APP_DIR:~-1%"==":" set "APP_DIR=%APP_DIR%\"

echo =============================================================
echo   Windows U 盘离线装机助手 - ISO 光盘镜像打包工具
echo =============================================================
echo.

where powershell.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未检测到 powershell.exe，无法启动打包工具。
    pause
    popd
    exit /b 1
)

if not exist "%APP_DIR%\Scripts\Build-ISO.ps1" (
    echo [错误] 未找到 Scripts\Build-ISO.ps1 脚本。
    pause
    popd
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%APP_DIR%\Scripts\Build-ISO.ps1" -UsbRoot "%APP_DIR%" %*

set "EXIT_CODE=%errorlevel%"
echo.
pause
popd
exit /b %EXIT_CODE%