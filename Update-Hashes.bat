@echo off
chcp 936 >nul 2>&1
setlocal EnableDelayedExpansion
pushd "%~dp0"
set "APP_DIR=%~dp0"
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"

echo =============================================================
echo   Windows U 盘离线装机助手 - 软件包 SHA256 自动计算维护工具
echo =============================================================
echo 正在扫描 Packages 目录并更新 Config\packages.ini 中的 SHA256...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
    ". '%APP_DIR%\Scripts\Utils.ps1'; . '%APP_DIR%\Scripts\Updater.ps1'; Update-LocalPackageHashes -UsbRoot '%APP_DIR%' -LogCallback { param($m) Write-Host $m }"

echo.
echo 处理完毕。
pause
popd
