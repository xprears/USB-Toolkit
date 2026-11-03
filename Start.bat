@echo off
:: 强制 CMD 使用简体中文代码页 (GBK)，杜绝控制台乱码
chcp 936 >nul 2>&1
setlocal EnableDelayedExpansion

:: -------------------------------------------------------------
:: Windows U 盘离线装机助手 - 引导启动入口
:: 兼容 Windows 7 SP1 / Windows 10 / Windows 11 (x64 / ARM64)
:: 解决 UNC 路径、Parallels 共享网络驱动器、UAC 提权等问题
:: -------------------------------------------------------------

:: 切换工作目录至批处理所在目录（使用 pushd 兼容 UNC 网络共享路径与临时盘符挂载）
pushd "%~dp0"
set "APP_DIR=%~dp0"

:: 去除 APP_DIR 末尾反斜杠（防止在传参时造成 \" 转义双引号导致参数解析错乱）
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"
:: 针对根目录 (例如 E:) 补齐反斜杠
if "%APP_DIR:~-1%"==":" set "APP_DIR=%APP_DIR%\"

:: 检查是否具备管理员权限 (若已具备权限则直接跳转运行)
net session >nul 2>&1
if %errorlevel% equ 0 goto :RUN_TOOLKIT
fltmc >nul 2>&1
if %errorlevel% equ 0 goto :RUN_TOOLKIT

:: 未具备管理员权限时，通过 PowerShell 调起 UAC 提权启动新的管理员窗口
echo [提示] 正在请求管理员权限以运行装机助手...

set "SCRIPT_PATH=%~f0"
set "SCRIPT_PATH=%SCRIPT_PATH:'=''%"

:: 采用 cmd.exe /k 调起新管理员窗口，确保即使执行出现异常窗口也绝对不会自动闪退
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath 'cmd.exe' -ArgumentList ('/k ""' + '%SCRIPT_PATH%' + '""') -Verb RunAs -ErrorAction Stop; exit 0 } catch { exit 1 }"
if %errorlevel% equ 0 (
    popd
    exit /b 0
)

echo.
echo [错误] 提权请求失败或已被用户取消！
echo 请手动右键点击 [Start.bat]，选择【以管理员身份运行】。
echo.
pause
popd
exit /b 1

:RUN_TOOLKIT
:: 检查 PowerShell 运行环境
where powershell.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [错误] 当前系统未检测到 powershell.exe，无法启动装机助手。
    echo 请确认系统已安装 Windows Management Framework / PowerShell。
    echo.
    pause
    popd
    exit /b 1
)

:: 检查核心 GUI 脚本是否存在
if not exist "%APP_DIR%\Scripts\GUI.ps1" (
    echo.
    echo [错误] 未在以下路径找到 GUI.ps1:
    echo "%APP_DIR%\Scripts\GUI.ps1"
    echo.
    echo 常见原因及排查方法:
    echo 1. 若在虚拟机中运行，请确保 U 盘已直接接入虚拟机（非 Mac 网络共享）；
    echo 2. 请确认 U 盘解压完整，Scripts 文件夹存在。
    echo.
    pause
    popd
    exit /b 1
)

:: 启动图形界面 (支持 Win7 SP1 PS2.0 及更高版本)
echo [信息] 正在加载 Windows 离线装机助手，请稍候...

powershell.exe -sta -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; try { & '%APP_DIR%\Scripts\GUI.ps1' -UsbRoot '%APP_DIR%' } catch { Write-Host ''; Write-Host ('[运行异常] ' + $_.Exception.Message) -ForegroundColor Red; Write-Host $_.Exception.ToString() -ForegroundColor DarkRed; exit 1 }; exit 0"

set "PS_EXIT_CODE=%errorlevel%"

if %PS_EXIT_CODE% equ 0 goto :RUN_SUCCESS

echo.
echo =============================================================
echo [提示] 装机助手运行异常，退出码: %PS_EXIT_CODE%
echo 请查看上方红色报错信息排查问题。
echo =============================================================
echo.
pause
popd
exit /b %PS_EXIT_CODE%

:RUN_SUCCESS
popd
exit 0
