# =============================================================
# Windows 离线装机助手 - 原生 ISO 光盘镜像生成脚本 (Windows 环境)
# 零外部依赖：使用 Windows 内置 IMAPI2 COM 接口，无需第三方软件
# =============================================================

param(
    [string]$UsbRoot = "",
    [string]$OutputIso = ""
)

$scriptDir = "."
if ($MyInvocation.MyCommand.Path) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} elseif ($MyInvocation.MyCommand.Definition) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

if ([string]::IsNullOrEmpty($UsbRoot)) {
    $UsbRoot = Split-Path -Parent $scriptDir
}
if ([string]::IsNullOrEmpty($OutputIso)) {
    $OutputIso = [System.IO.Path]::Combine($UsbRoot, "USB-Toolkit.iso")
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  正在打包 Windows 离线装机助手 ISO 光盘镜像..." -ForegroundColor Cyan
Write-Host "  源码根目录: $UsbRoot"
Write-Host "  输出目标:   $OutputIso"
Write-Host "==================================================" -ForegroundColor Cyan

# 1. 创建临时暂存区，过滤排除 git、日志等无关文件
$tempDir = [System.Environment]::GetEnvironmentVariable("TEMP")
if ([string]::IsNullOrEmpty($tempDir)) { $tempDir = "C:\Windows\Temp" }
$stagingDir = [System.IO.Path]::Combine($tempDir, "USB-Toolkit-ISO-Staging")

if (Test-Path $stagingDir) {
    Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
}
[void](New-Item -ItemType Directory -Path $stagingDir -Force)

Write-Host "[1/3] 正在复制文件至临时光盘暂存区..." -ForegroundColor Yellow

$excludeDirs = @(".git", ".idea", ".vscode")
$excludeFiles = @("*.iso", "*.tmp", "*.bak", ".DS_Store")

Get-ChildItem -Path $UsbRoot -Force | ForEach-Object {
    $name = $_.Name
    if ($_.PSIsContainer) {
        if ($excludeDirs -notcontains $name) {
            $dest = [System.IO.Path]::Combine($stagingDir, $name)
            Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
        }
    } else {
        $skip = $false
        foreach ($pat in $excludeFiles) {
            if ($name -like $pat) { $skip = $true; break }
        }
        if (-not $skip) {
            Copy-Item -Path $_.FullName -Destination $stagingDir -Force
        }
    }
}

# 清理暂存区内 Logs 下的历史日志，仅保留占位
$stagingLogs = [System.IO.Path]::Combine($stagingDir, "Logs")
if (Test-Path $stagingLogs) {
    Get-ChildItem -Path $stagingLogs -Filter "*.log" -File | Remove-Item -Force -ErrorAction SilentlyContinue
}

# 2. 调用 Windows IMAPI2 COM 接口生成 ISO 镜像
Write-Host "[2/3] 正在生成 Joliet/ISO9660 格式 ISO 镜像..." -ForegroundColor Yellow

try {
    $fsi = New-Object -ComObject IMAPI2.MsftFileSystemImage
    $fsi.ChooseImageDefaultsForMediaType(12)
    $fsi.FileSystemsToCreate = 3
    $fsi.VolumeName = "USB_TOOLKIT"

    $fsi.Root.AddTree($stagingDir, $false)
    $resultImage = $fsi.CreateResultImage()
    $stream = $resultImage.ImageStream

    if (Test-Path $OutputIso) {
        Remove-Item $OutputIso -Force -ErrorAction SilentlyContinue
    }

    $bufferSize = 2097152
    $buffer = New-Object byte[] $bufferSize
    $fileStream = New-Object System.IO.FileStream($OutputIso, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)

    $comStream = [System.Runtime.InteropServices.ComTypes.IStream]$stream
    $bytesReadIntPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4)

    try {
        while ($true) {
            [System.Runtime.InteropServices.Marshal]::WriteInt32($bytesReadIntPtr, 0)
            $comStream.Read($buffer, $bufferSize, $bytesReadIntPtr)
            $read = [System.Runtime.InteropServices.Marshal]::ReadInt32($bytesReadIntPtr)
            if ($read -le 0) { break }
            $fileStream.Write($buffer, 0, $read)
        }
    } finally {
        $fileStream.Close()
        $fileStream.Dispose()
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($bytesReadIntPtr)
    }

    $isoItem = Get-Item $OutputIso
    $sizeMB = $isoItem.Length / 1048576.0
    Write-Host "[3/3] 清理临时暂存区..." -ForegroundColor Yellow
    Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "==================================================" -ForegroundColor Green
    Write-Host ("✅ ISO 光盘镜像打包成功！大小: {0:N2} MB" -f $sizeMB) -ForegroundColor Green
    Write-Host "  输出文件: $OutputIso" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
} catch {
    Write-Host "[错误] ISO 打包失败: $($_.Exception.Message)" -ForegroundColor Red
    Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}