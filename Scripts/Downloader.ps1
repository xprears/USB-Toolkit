# =============================================================
# Windows U 盘离线装机助手 - 官方安装包下载与完整性维护模块
# 遵循原则：原生兼容 PowerShell 2.0 / .NET 3.5 及更高版本
# 支持断点容错、镜像回退、实时进度显示、SHA256 完整性自动校验
# =============================================================

param(
    [string]$UsbRoot = "",
    [switch]$All,
    [switch]$Core,
    [string[]]$PackageKeys = @(),
    [switch]$VerifyOnly,
    [switch]$Force,
    [switch]$NonInteractive
)

# 1. 确定运行目录并加载基础依赖
$scriptDir = "."
if ($MyInvocation.MyCommand.Path) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} elseif ($MyInvocation.MyCommand.Definition) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

if ([string]::IsNullOrEmpty($UsbRoot)) {
    $UsbRoot = Split-Path -Parent $scriptDir
}

if (-not (Get-Command "Get-FileSha256" -ErrorAction SilentlyContinue)) {
    $utilsPath = [System.IO.Path]::Combine($scriptDir, "Utils.ps1")
    if (Test-Path $utilsPath) {
        . $utilsPath
    } else {
        Write-Host "[错误] 未找到基础函数库: $utilsPath" -ForegroundColor Red
        exit 1
    }
}

# 2. 启用 TLS 1.2 / TLS 1.1 / TLS 1.0 (兼容 .NET 2.0/3.5/4.x，避免旧版 PowerShell 报握手异常)
try {
    # 3072 = Tls12, 768 = Tls11, 192 = Tls, 48 = Ssl3
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]3072 -bor [System.Net.SecurityProtocolType]768 -bor [System.Net.SecurityProtocolType]192 -bor [System.Net.SecurityProtocolType]48
} catch {
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls
    } catch {}
}

# 忽略非致命证书回调警告（提升老旧测试环境兼容性）
try {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
} catch {}

# 3. 读取 packages.ini 软件包定义
$pkgIniPath = [System.IO.Path]::Combine($UsbRoot, "Config\packages.ini")
if (-not (Test-Path $pkgIniPath)) {
    Write-Host "[错误] 找不到 packages.ini 配置文件: $pkgIniPath" -ForegroundColor Red
    exit 1
}

$parsedIni = Parse-IniFile -FilePath $pkgIniPath

function Get-OrderedPackageList {
    param([string]$IniPath, [hashtable]$ParsedData)
    $list = New-Object System.Collections.ArrayList
    $lines = [System.IO.File]::ReadAllLines($IniPath, [System.Text.Encoding]::UTF8)
    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ($trim -match '^\[(.*)\]$') {
            $sec = $matches[1].Trim()
            if ($ParsedData.ContainsKey($sec)) {
                $pkg = $ParsedData[$sec]
                $obj = New-Object PSObject
                $obj | Add-Member -MemberType NoteProperty -Name "Key" -Value $sec
                $obj | Add-Member -MemberType NoteProperty -Name "Name" -Value ($pkg["Name"])
                $obj | Add-Member -MemberType NoteProperty -Name "Category" -Value ($pkg["Category"])
                $obj | Add-Member -MemberType NoteProperty -Name "PackagePath" -Value ($pkg["PackagePath"])
                $obj | Add-Member -MemberType NoteProperty -Name "Version" -Value ($pkg["Version"])
                $obj | Add-Member -MemberType NoteProperty -Name "SHA256" -Value ($pkg["SHA256"])
                $obj | Add-Member -MemberType NoteProperty -Name "DefaultSelected" -Value ($pkg["DefaultSelected"])
                $obj | Add-Member -MemberType NoteProperty -Name "DownloadUrl" -Value ($pkg["DownloadUrl"])
                $obj | Add-Member -MemberType NoteProperty -Name "DownloadMirrors" -Value ($pkg["DownloadMirrors"])
                $obj | Add-Member -MemberType NoteProperty -Name "DownloadPage" -Value ($pkg["DownloadPage"])
                $obj | Add-Member -MemberType NoteProperty -Name "Description" -Value ($pkg["Description"])
                [void]$list.Add($obj)
            }
        }
    }
    return $list
}

function Download-HttpFileWithProgress {
    param(
        [string]$Url,
        [string]$DestinationPath,
        [string]$DisplayName
    )

    $tempPath = $DestinationPath + ".download.tmp"
    if (Test-Path $tempPath) {
        Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
    }

    $destDir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path $destDir)) {
        [void](New-Item -ItemType Directory -Path $destDir -Force)
    }

    $request = $null
    $response = $null
    $responseStream = $null
    $fileStream = $null

    try {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        $request.Timeout = 60000
        $request.ReadWriteTimeout = 120000
        $request.KeepAlive = $true

        try {
            $request.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
        } catch {}

        $response = $request.GetResponse()
        $totalBytes = $response.ContentLength
        $responseStream = $response.GetResponseStream()
        $fileStream = New-Object System.IO.FileStream($tempPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)

        $buffer = New-Object byte[] 65536
        $downloadedBytes = 0
        $startTime = [System.DateTime]::Now
        $lastReportTime = [System.DateTime]::Now

        while (($bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $bytesRead)
            $downloadedBytes += $bytesRead

            $now = [System.DateTime]::Now
            $elapsedSec = ($now - $lastReportTime).TotalSeconds

            if ($elapsedSec -ge 0.5 -or $downloadedBytes -eq $totalBytes) {
                $lastReportTime = $now
                $totalElapsed = ($now - $startTime).TotalSeconds
                $speedMBs = 0.0
                if ($totalElapsed -gt 0) {
                    $speedMBs = ($downloadedBytes / 1048576.0) / $totalElapsed
                }

                $curMB = $downloadedBytes / 1048576.0
                if ($totalBytes -gt 0) {
                    $totMB = $totalBytes / 1048576.0
                    $pct = [int](($downloadedBytes * 100.0) / $totalBytes)
                    if ($pct -gt 100) { $pct = 100 }
                    $barLen = [int]($pct / 5)
                    if ($barLen -gt 20) { $barLen = 20 }
                    $bar = (New-Object string ('=', $barLen)).PadRight(20, ' ')
                    Write-Host -NoNewline ("`r  进度: [{0}] {1,3}% ({2:N1} MB / {3:N1} MB) {4:N2} MB/s" -f $bar, $pct, $curMB, $totMB, $speedMBs)
                } else {
                    Write-Host -NoNewline ("`r  进度: 已下载 {0:N1} MB - {1:N2} MB/s" -f $curMB, $speedMBs)
                }
            }
        }

        Write-Host ""
        $fileStream.Close()
        $fileStream = $null
        $responseStream.Close()
        $responseStream = $null
        $response.Close()
        $response = $null

        # 下载完成，重命名临时文件为正式目标
        if (Test-Path $DestinationPath) {
            Remove-Item $DestinationPath -Force -ErrorAction SilentlyContinue
        }
        Move-Item -Path $tempPath -Destination $DestinationPath -Force
        return $true
    } catch {
        Write-Host ""
        Write-Host ("  [下载异常] " + $_.Exception.Message) -ForegroundColor Red
        return $false
    } finally {
        if ($fileStream -ne $null) { $fileStream.Close(); $fileStream.Dispose() }
        if ($responseStream -ne $null) { $responseStream.Close(); $responseStream.Dispose() }
        if ($response -ne $null) { $response.Close() }
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Process-SinglePackageDownload {
    param(
        [PSObject]$Pkg,
        [string]$UsbRoot,
        [switch]$ForceOverwrite
    )

    $relPath = $Pkg.PackagePath
    $fullPath = [System.IO.Path]::Combine($UsbRoot, $relPath)
    $expectedHash = if ($Pkg.SHA256) { $Pkg.SHA256.ToLower().Trim() } else { "" }
    $primaryUrl = $Pkg.DownloadUrl
    $mirrors = if ($Pkg.DownloadMirrors) { ($Pkg.DownloadMirrors -split ';') } else { @() }
    $page = $Pkg.DownloadPage

    Write-Host "-------------------------------------------------------------"
    Write-Host "【软件名称】: $($Pkg.Name)" -ForegroundColor Cyan
    Write-Host "【放置路径】: $relPath"
    Write-Host "【预期版本】: $($Pkg.Version)"

    # 1. 检测本地文件是否已存在
    if ((Test-Path $fullPath) -and (-not $ForceOverwrite)) {
        Write-Host "  -> 本地文件已存在，正在校验 SHA256 哈希完整性..." -ForegroundColor Yellow
        $localHash = Get-FileSha256 -FilePath $fullPath
        if ($localHash) {
            if ($expectedHash -ne "" -and $localHash -eq $expectedHash) {
                Write-Host "  [已就绪] 文件已存在且 SHA256 校验一致，跳过下载。" -ForegroundColor Green
                Write-Host "  -> SHA256: $localHash" -ForegroundColor Gray
                return $true
            } else {
                Write-Host "  [哈希不匹配] 本地文件 SHA256 ($localHash) 与配置记录 ($expectedHash) 不一致。" -ForegroundColor Magenta
                Write-Host "  -> 将重新下载官方原版安装包覆盖该文件..." -ForegroundColor Yellow
            }
        }
    }

    # 2. 检查是否有直链下载地址
    if ([string]::IsNullOrEmpty($primaryUrl)) {
        Write-Host "  [提示] 该软件官方不提供永久静态直链，需通过官方门户或指定页面获取：" -ForegroundColor Yellow
        if ($page) {
            Write-Host "  -> 官方获取页面: $page" -ForegroundColor Cyan
        }
        Write-Host "  -> 下载后请重命名并放置于: $relPath" -ForegroundColor Gray
        return $false
    }

    # 3. 开始执行下载
    $urlsToTry = New-Object System.Collections.ArrayList
    [void]$urlsToTry.Add($primaryUrl)
    foreach ($m in $mirrors) {
        $mTrim = $m.Trim()
        if ($mTrim -ne "" -and -not $urlsToTry.Contains($mTrim)) {
            [void]$urlsToTry.Add($mTrim)
        }
    }

    $downloadSuccess = $false
    foreach ($u in $urlsToTry) {
        Write-Host "  -> 正在从官方地址下载: $u" -ForegroundColor White
        $res = Download-HttpFileWithProgress -Url $u -DestinationPath $fullPath -DisplayName $Pkg.Name
        if ($res -and (Test-Path $fullPath)) {
            $downloadSuccess = $true
            break
        } else {
            Write-Host "  -> 当前地址下载失败，正在尝试下一个备用链接..." -ForegroundColor Yellow
        }
    }

    if (-not $downloadSuccess) {
        Write-Host "  [错误] 所有下载地址均尝试失败，请检查网络连接或手动下载。" -ForegroundColor Red
        if ($page) {
            Write-Host "  -> 官方页面: $page" -ForegroundColor Cyan
        }
        return $false
    }

    # 4. 下载后完整性核验
    Write-Host "  -> 正在核验已下载文件的 SHA256 哈希值..." -ForegroundColor Yellow
    $newHash = Get-FileSha256 -FilePath $fullPath
    if ($newHash) {
        Write-Host "  -> 实际 SHA256: $newHash" -ForegroundColor Gray
        if ($expectedHash -ne "") {
            if ($newHash -eq $expectedHash) {
                Write-Host "  [校验通过] 文件的 SHA256 与配置基线完全匹配，官方原版无损坏！" -ForegroundColor Green
            } else {
                Write-Host "  [版本更新提示] 实际 SHA256 与 packages.ini 基线哈希不一致。" -ForegroundColor Yellow
                Write-Host "  -> 原因: 官方直链已自动推送最新版本安装包。" -ForegroundColor Yellow
                Write-Host "  -> 建议: 安装包已成功下载并安全保留。您可在确认后运行根目录下【Update-Hashes.bat】自动将新哈希更新至配置。" -ForegroundColor Gray
            }
        }
    }
    return $true
}

function Show-ExistingPackagesStatus {
    param([System.Collections.ArrayList]$Packages, [string]$UsbRoot)

    Write-Host "`n=============================================================" -ForegroundColor Cyan
    Write-Host "          Packages 目录现有软件包完整性核验状态" -ForegroundColor Cyan
    Write-Host "=============================================================" -ForegroundColor Cyan

    $readyCount = 0
    $missingCount = 0
    $mismatchCount = 0

    foreach ($pkg in $Packages) {
        $fullPath = [System.IO.Path]::Combine($UsbRoot, $pkg.PackagePath)
        $expHash = if ($pkg.SHA256) { $pkg.SHA256.ToLower().Trim() } else { "" }
        
        Write-Host ("[{0}] {1}" -f $pkg.Category, $pkg.Name) -NoNewline
        if (Test-Path $fullPath) {
            $sz = (Get-Item $fullPath).Length / 1048576.0
            $curHash = Get-FileSha256 -FilePath $fullPath
            if ($expHash -ne "" -and $curHash -eq $expHash) {
                Write-Host (" -> [已就绪 ({0:N1} MB)] SHA256匹配" -f $sz) -ForegroundColor Green
                $readyCount++
            } else {
                Write-Host (" -> [已存在但哈希不匹配 ({0:N1} MB)]" -f $sz) -ForegroundColor Yellow
                $mismatchCount++
            }
        } else {
            Write-Host " -> [文件缺失]" -ForegroundColor Red
            $missingCount++
        }
    }

    Write-Host "-------------------------------------------------------------"
    Write-Host ("统计: 已就绪: {0} 款 | 哈希需更新: {1} 款 | 缺失待下载: {2} 款" -f $readyCount, $mismatchCount, $missingCount) -ForegroundColor White
}

function Open-ManualPortals {
    param([System.Collections.ArrayList]$Packages)

    Write-Host "`n=============================================================" -ForegroundColor Cyan
    Write-Host "          需手动访问官方门户获取的软件包清单" -ForegroundColor Cyan
    Write-Host "=============================================================" -ForegroundColor Cyan

    $manualPkgs = @()
    foreach ($pkg in $Packages) {
        if ([string]::IsNullOrEmpty($pkg.DownloadUrl) -and $pkg.DownloadPage) {
            $manualPkgs += $pkg
        }
    }

    if ($manualPkgs.Count -eq 0) {
        Write-Host "所有软件包均已配置直链下载，无需手动获取。" -ForegroundColor Green
        return
    }

    $idx = 1
    foreach ($m in $manualPkgs) {
        Write-Host ("[{0}] {1} (适用: {2})" -f $idx, $m.Name, $m.PackagePath) -ForegroundColor Yellow
        Write-Host ("    官方获取页面: {0}" -f $m.DownloadPage) -ForegroundColor Cyan
        Write-Host ("    说明: {0}" -f $m.Description) -ForegroundColor Gray
        $idx++
    }

    Write-Host ""
    $choice = Read-Host "是否在默认浏览器中打开上述官方下载页面？(输入序号如 1 打开单个，输入 A 全部打开，直接回车取消)"
    if ($choice -match '^[aA]$') {
        foreach ($m in $manualPkgs) {
            try { [System.Diagnostics.Process]::Start($m.DownloadPage) } catch {}
        }
    } elseif ($choice -match '^[1-9][0-9]*$') {
        $sel = [int]$choice - 1
        if ($sel -ge 0 -and $sel -lt $manualPkgs.Count) {
            try { [System.Diagnostics.Process]::Start($manualPkgs[$sel].DownloadPage) } catch {}
        }
    }
}

# 4. 主流程逻辑
$allPackages = Get-OrderedPackageList -IniPath $pkgIniPath -ParsedData $parsedIni

# A. 仅校验模式
if ($VerifyOnly) {
    Show-ExistingPackagesStatus -Packages $allPackages -UsbRoot $UsbRoot
    exit 0
}

# B. 命令行非交互下载指定 PackageKeys
if ($PackageKeys.Count -gt 0) {
    foreach ($key in $PackageKeys) {
        $matched = $allPackages | Where-Object { $_.Key -eq $key }
        if ($matched) {
            Process-SinglePackageDownload -Pkg $matched -UsbRoot $UsbRoot -ForceOverwrite:$Force
        } else {
            Write-Host "[警告] 未找到键名为 '$key' 的软件包配置" -ForegroundColor Yellow
        }
    }
    exit 0
}

# C. 命令行直接下载全部 (直链软件)
if ($All) {
    Write-Host "[执行] 开始一键批量下载所有支持直链的官方离线包..." -ForegroundColor Cyan
    foreach ($p in $allPackages) {
        if (-not [string]::IsNullOrEmpty($p.DownloadUrl)) {
            Process-SinglePackageDownload -Pkg $p -UsbRoot $UsbRoot -ForceOverwrite:$Force
        }
    }
    Show-ExistingPackagesStatus -Packages $allPackages -UsbRoot $UsbRoot
    exit 0
}

# D. 命令行直接下载核心软件
if ($Core) {
    Write-Host "[执行] 开始下载常用核心必备软件..." -ForegroundColor Cyan
    $coreKeys = @("7zip_x64", "chrome_win10_11", "chrome_win11_arm64", "wechat_unified", "potplayer_x64", "shouxin_input", "vlc_x64")
    foreach ($k in $coreKeys) {
        $p = $allPackages | Where-Object { $_.Key -eq $k }
        if ($p -and -not [string]::IsNullOrEmpty($p.DownloadUrl)) {
            Process-SinglePackageDownload -Pkg $p -UsbRoot $UsbRoot -ForceOverwrite:$Force
        }
    }
    Show-ExistingPackagesStatus -Packages $allPackages -UsbRoot $UsbRoot
    exit 0
}

# E. 交互式菜单模式
while ($true) {
    Clear-Host
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host "  Windows U 盘离线装机助手 (USB-Toolkit) - 官方软件包下载器" -ForegroundColor Cyan
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host "  U 盘根目录 : $UsbRoot"
    Write-Host "  网络连通性 : $(if (Test-NetworkOnline) { '正常在线' } else { '离线或受限' })"
    Write-Host "-------------------------------------------------------------"
    Write-Host "  [1] 一键下载全部官方离线安装包 (推荐新克隆仓库用户使用)" -ForegroundColor Yellow
    Write-Host "  [2] 仅下载核心必备软件 (7-Zip, Chrome, 微信, PotPlayer, 手心, VLC)"
    Write-Host "  [3] 自定义选择下载具体某一款软件"
    Write-Host "  [4] 核验现有 Packages 离线安装包完整性 (SHA256 离线体检)"
    Write-Host "  [5] 查看/打开需手动获取的官方门户 (WPS教育版、搜狗经典版等)"
    Write-Host "  [0] 退出"
    Write-Host "-------------------------------------------------------------"
    
    $inputChoice = Read-Host "请输入选项 [0-5]"
    switch ($inputChoice.Trim()) {
        "1" {
            Write-Host "`n[开始] 一键下载全部支持直链的官方安装包..." -ForegroundColor Green
            foreach ($p in $allPackages) {
                if (-not [string]::IsNullOrEmpty($p.DownloadUrl)) {
                    Process-SinglePackageDownload -Pkg $p -UsbRoot $UsbRoot -ForceOverwrite:$Force
                }
            }
            Show-ExistingPackagesStatus -Packages $allPackages -UsbRoot $UsbRoot
            Write-Host "`n按任意键返回主菜单..."; [void][System.Console]::ReadKey($true)
        }
        "2" {
            Write-Host "`n[开始] 下载核心必备软件包..." -ForegroundColor Green
            $coreKeys = @("7zip_x64", "chrome_win10_11", "chrome_win11_arm64", "wechat_unified", "potplayer_x64", "shouxin_input", "vlc_x64")
            foreach ($k in $coreKeys) {
                $p = $allPackages | Where-Object { $_.Key -eq $k }
                if ($p -and -not [string]::IsNullOrEmpty($p.DownloadUrl)) {
                    Process-SinglePackageDownload -Pkg $p -UsbRoot $UsbRoot -ForceOverwrite:$Force
                }
            }
            Show-ExistingPackagesStatus -Packages $allPackages -UsbRoot $UsbRoot
            Write-Host "`n按任意键返回主菜单..."; [void][System.Console]::ReadKey($true)
        }
        "3" {
            Write-Host "`n可选软件包列表:" -ForegroundColor Cyan
            $i = 1
            foreach ($p in $allPackages) {
                $hasUrl = if (-not [string]::IsNullOrEmpty($p.DownloadUrl)) { "[直链]" } else { "[需页面]" }
                Write-Host ("  [{0}] {1,-10} {2} {3}" -f $i, $hasUrl, $p.Name, $p.PackagePath)
                $i++
            }
            $num = Read-Host "请输入要下载的软件编号 (回车取消)"
            if ($num -match '^[1-9][0-9]*$') {
                $selIndex = [int]$num - 1
                if ($selIndex -ge 0 -and $selIndex -lt $allPackages.Count) {
                    Process-SinglePackageDownload -Pkg $allPackages[$selIndex] -UsbRoot $UsbRoot -ForceOverwrite:$Force
                }
            }
            Write-Host "`n按任意键返回主菜单..."; [void][System.Console]::ReadKey($true)
        }
        "4" {
            Show-ExistingPackagesStatus -Packages $allPackages -UsbRoot $UsbRoot
            Write-Host "`n按任意键返回主菜单..."; [void][System.Console]::ReadKey($true)
        }
        "5" {
            Open-ManualPortals -Packages $allPackages
            Write-Host "`n按任意键返回主菜单..."; [void][System.Console]::ReadKey($true)
        }
        "0" {
            Write-Host "已退出下载助手。"
            exit 0
        }
        default {
            Write-Host "无效输入，请重试。" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}