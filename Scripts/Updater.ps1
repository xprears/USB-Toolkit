# =============================================================
# Windows U 盘离线装机助手 - 在线更新与哈希维护模块
# 遵循原则：离线优先，有网支持扩展检测；兼容 PowerShell 2.0 / .NET 3.5
# =============================================================

$scriptDir = "."
if ($MyInvocation.MyCommand.Path) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} elseif ($MyInvocation.MyCommand.Definition) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
if (-not (Get-Command "Get-OSInfo" -ErrorAction SilentlyContinue)) {
    . ([System.IO.Path]::Combine($scriptDir, "Utils.ps1"))
}

function Update-LocalPackageHashes {
    <#
    .SYNOPSIS
        扫描 Packages 目录并自动计算/回填 SHA256 哈希值至 packages.ini
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UsbRoot,
        [scriptblock]$LogCallback = $null
    )

    $pkgIniPath = [System.IO.Path]::Combine($UsbRoot, "Config\packages.ini")
    if (-not (Test-Path $pkgIniPath)) {
        if ($LogCallback) { & $LogCallback "[错误] 未找到 packages.ini 配置文件" }
        return $false
    }

    $lines = [System.IO.File]::ReadAllLines($pkgIniPath, [System.Text.Encoding]::UTF8)
    $newLines = New-Object System.Collections.ArrayList

    $currentSection = ""
    $currentPkgPath = ""

    # 先完整解析现有配置
    $parsedIni = Parse-IniFile -FilePath $pkgIniPath

    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ($trim -match '^\[(.*)\]$') {
            $currentSection = $matches[1].Trim()
            $currentPkgPath = ""
            if ($parsedIni.ContainsKey($currentSection) -and $parsedIni[$currentSection].ContainsKey("PackagePath")) {
                $currentPkgPath = $parsedIni[$currentSection]["PackagePath"]
            }
            [void]$newLines.Add($line)
            continue
        }

        # 检查是否为 SHA256 这一行
        if ($trim.StartsWith("SHA256=") -and $currentSection -ne "" -and $currentPkgPath -ne "") {
            $fullPath = [System.IO.Path]::Combine($UsbRoot, $currentPkgPath)
            if (Test-Path $fullPath) {
                $hash = Get-FileSha256 -FilePath $fullPath
                if ($hash) {
                    $newLine = "SHA256=$hash"
                    [void]$newLines.Add($newLine)
                    if ($LogCallback) { & $LogCallback "[更新哈希] [$currentSection] -> $hash" }
                    continue
                }
            }
        }

        [void]$newLines.Add($line)
    }

    [System.IO.File]::WriteAllLines($pkgIniPath, $newLines.ToArray([string]), [System.Text.Encoding]::UTF8)
    if ($LogCallback) { & $LogCallback "[完成] packages.ini 中的 SHA256 哈希值已全部核验更新" }
    return $true
}

function Check-OnlinePackageUpdates {
    <#
    .SYNOPSIS
        在线检测是否有新版本软件包元数据
    .DESCRIPTION
        若离线则平滑返回；若在线则可拉取配置清单对比版本。兼容 .NET 2.0 WebClient。
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$UsbRoot,
        [string]$RemoteManifestUrl = "",
        [scriptblock]$LogCallback = $null
    )

    $result = New-Object PSObject
    $result | Add-Member -MemberType NoteProperty -Name "IsOnline" -Value $false
    $result | Add-Member -MemberType NoteProperty -Name "HasUpdates" -Value $false
    $result | Add-Member -MemberType NoteProperty -Name "UpdateList" -Value @()
    $result | Add-Member -MemberType NoteProperty -Name "Message" -Value ""

    $online = Test-NetworkOnline
    $result.IsOnline = $online

    if (-not $online) {
        $result.Message = "当前处于全离线环境，在线更新已停用，全部依赖 U 盘离线包。"
        if ($LogCallback) { & $LogCallback "[离线感知] $($result.Message)" }
        return $result
    }

    if ([string]::IsNullOrEmpty($RemoteManifestUrl)) {
        $result.Message = "已连接外网，但未配置远端更新清单地址 (RemoteManifestUrl)。"
        if ($LogCallback) { & $LogCallback "[提示] $($result.Message)" }
        return $result
    }

    if ($LogCallback) { & $LogCallback "[在线更新] 正在检查远端更新清单: $RemoteManifestUrl" }

    $tempFile = [System.IO.Path]::Combine($UsbRoot, "Logs\remote_manifest.tmp")
    $webClient = $null
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "USB-Toolkit/1.2")
        $webClient.DownloadFile($RemoteManifestUrl, $tempFile)

        if (Test-Path $tempFile) {
            $remoteConfig = Parse-IniFile -FilePath $tempFile
            $localConfigPath = [System.IO.Path]::Combine($UsbRoot, "Config\packages.ini")
            $localConfig = Parse-IniFile -FilePath $localConfigPath

            $updates = @()
            foreach ($k in $remoteConfig.Keys) {
                if ($localConfig.ContainsKey($k)) {
                    $localVer = $localConfig[$k]["Version"]
                    $remoteVer = $remoteConfig[$k]["Version"]
                    $comp = Compare-SoftwareVersion -InstalledVersion $localVer -TargetVersion $remoteVer
                    if ($comp -eq -1) {
                        # 远端版本更高
                        $updates += @{
                            Key = $k;
                            Name = $localConfig[$k]["Name"];
                            LocalVersion = $localVer;
                            RemoteVersion = $remoteVer;
                        }
                    }
                }
            }

            if ($updates.Count -gt 0) {
                $result.HasUpdates = $true
                $result.UpdateList = $updates
                $result.Message = "发现 $($updates.Count) 款软件存在远端新版本更新。"
            } else {
                $result.HasUpdates = $false
                $result.Message = "当前 U 盘离线软件包已为最新状态。"
            }
        }
    } catch {
        $result.Message = "检查在线更新失败: $($_.Exception.Message)"
        if ($LogCallback) { & $LogCallback "[警告] $($result.Message)" }
    } finally {
        if ($webClient -ne $null) { $webClient.Dispose() }
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
    }

    return $result
}
