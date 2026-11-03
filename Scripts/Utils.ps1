# =============================================================
# Windows U 盘离线装机助手 - 基础工具与系统检测模块
# 严格兼容: Windows PowerShell 2.0 (.NET 2.0/3.5 on Win7 SP1) 及更高版本
# =============================================================

function Get-OSInfo {
    <#
    .SYNOPSIS
        检测当前操作系统的版本、架构及 Service Pack 状态
    .DESCRIPTION
        使用注册表与环境信息综合判断，精确区分 Windows 7 SP1、Windows 10 和 Windows 11
    #>
    $osInfo = New-Object PSObject
    $osInfo | Add-Member -MemberType NoteProperty -Name "OSCode" -Value "Unsupported"
    $osInfo | Add-Member -MemberType NoteProperty -Name "OSName" -Value "未知操作系统"
    $osInfo | Add-Member -MemberType NoteProperty -Name "Arch" -Value "x86"
    $osInfo | Add-Member -MemberType NoteProperty -Name "BuildNumber" -Value 0
    $osInfo | Add-Member -MemberType NoteProperty -Name "MajorVersion" -Value 0
    $osInfo | Add-Member -MemberType NoteProperty -Name "MinorVersion" -Value 0
    $osInfo | Add-Member -MemberType NoteProperty -Name "IsSP1" -Value $false
    $osInfo | Add-Member -MemberType NoteProperty -Name "IsSupported" -Value $false
    $osInfo | Add-Member -MemberType NoteProperty -Name "DisplaySummary" -Value ""

    # 1. 架构检测 (支持 x86, x64, ARM64 以及 WOW64 仿真环境)
    $arch = $env:PROCESSOR_ARCHITECTURE
    $arch64 = $env:PROCESSOR_ARCHITEW6432
    if ($arch -eq "ARM64" -or $arch64 -eq "ARM64") {
        $osInfo.Arch = "ARM64"
    } elseif ($arch -eq "AMD64" -or $arch64 -eq "AMD64") {
        $osInfo.Arch = "x64"
    } else {
        $osInfo.Arch = "x86"
    }

    # 2. 读取注册表获取准确的版本与构建号 (避开 GetVersionEx 在高版本的兼容模式截断)
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $productName = ""
    $buildNumber = 0
    $csdVersion = ""
    $major = 0
    $minor = 0

    if (Test-Path $regPath) {
        $reg = Get-ItemProperty -Path $regPath
        if ($reg.ProductName) { $productName = [string]$reg.ProductName }
        if ($reg.CSDVersion) { $csdVersion = [string]$reg.CSDVersion }
        
        # Windows 10 / 11 具有 CurrentMajorVersionNumber
        if ($reg.CurrentMajorVersionNumber -ne $null) {
            $major = [int]$reg.CurrentMajorVersionNumber
            $minor = [int]$reg.CurrentMinorVersionNumber
            $buildNumber = [int]$reg.CurrentBuildNumber
        } elseif ($reg.CurrentVersion) {
            # Windows 7 或旧版: CurrentVersion 通常为 "6.1"
            $parts = [string]$reg.CurrentVersion -split '\.'
            if ($parts.Length -ge 1) { $major = [int]$parts[0] }
            if ($parts.Length -ge 2) { $minor = [int]$parts[1] }
            if ($reg.CurrentBuildNumber) { $buildNumber = [int]$reg.CurrentBuildNumber }
        }
    }

    # 回退机制: 如果注册表未读到构建号，使用 Environment.OSVersion
    if ($buildNumber -eq 0) {
        $ver = [System.Environment]::OSVersion.Version
        $major = $ver.Major
        $minor = $ver.Minor
        $buildNumber = $ver.Build
    }

    $osInfo.MajorVersion = $major
    $osInfo.MinorVersion = $minor
    $osInfo.BuildNumber = $buildNumber

    # 3. 判断系统类型
    if ($major -eq 6 -and $minor -eq 1) {
        # Windows 7 (NT 6.1, Build 7600 或 7601 SP1)
        $isSP1 = ($buildNumber -ge 7601) -or ($csdVersion -like "*Service Pack 1*")
        $osInfo.IsSP1 = $isSP1
        $osInfo.OSCode = "Win7"
        if ($isSP1) {
            $osInfo.OSName = "Windows 7 SP1"
            if ($osInfo.Arch -eq "x64") {
                $osInfo.IsSupported = $true
            }
        } else {
            $osInfo.OSName = "Windows 7 (未安装 SP1，不满足运行要求)"
            $osInfo.IsSupported = $false
        }
    } elseif ($major -ge 10) {
        # Windows 10 与 Windows 11 (NT 10.0)
        if ($buildNumber -ge 22000) {
            $osInfo.OSCode = "Win11"
            $osInfo.OSName = "Windows 11"
        } else {
            $osInfo.OSCode = "Win10"
            $osInfo.OSName = "Windows 10"
        }
        # x64 原生支持，ARM64 (如 Parallels/Copilot+ PC 等具备 Prism/x64转译仿真) 均予以支持
        if ($osInfo.Arch -eq "x64" -or $osInfo.Arch -eq "ARM64") {
            $osInfo.IsSupported = $true
        }
    } else {
        $osInfo.OSCode = "Unsupported"
        $osInfo.OSName = "不支持的系统 (NT $major.$minor, Build $buildNumber)"
        $osInfo.IsSupported = $false
    }

    $osInfo.DisplaySummary = "$($osInfo.OSName) $($osInfo.Arch) (Build $buildNumber)"
    return $osInfo
}

function Test-NetworkOnline {
    <#
    .SYNOPSIS
        检测当前网络连接状态（兼容离线无网环境）
    #>
    try {
        $isInterfaceUp = [System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable()
        if (-not $isInterfaceUp) {
            return $false
        }
        $ping = New-Object System.Net.NetworkInformation.Ping
        $reply = $ping.Send("223.5.5.5", 800)
        if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            return $true
        }
        $reply2 = $ping.Send("119.29.29.29", 800)
        return ($reply2.Status -eq [System.Net.NetworkInformation.IPStatus]::Success)
    } catch {
        return $false
    }
}

function Test-Win7UcrtPrerequisite {
    <#
    .SYNOPSIS
        检测 Windows 7 系统是否已具备 Universal C Runtime (KB2999226) 前置运行库
    .DESCRIPTION
        严格区分 UCRT 文件存在性与 KB2999226 补丁安装状态。
        状态输出明确分为：
        - ComponentPresent (组件存在): 核心 DLL 文件存在且注册表检测到补丁记录
        - ComponentMissing (组件缺失): 系统核心 DLL 缺失且无补丁记录
        - Inconclusive (无法确认): 检测到 DLL 文件但未见补丁记录，或补丁检测受限
        原则：只做状态检测与告警，绝不自动调用外部补丁安装程序。
    #>
    $result = New-Object PSObject
    $result | Add-Member -MemberType NoteProperty -Name "StatusCode" -Value "ComponentPresent"
    $result | Add-Member -MemberType NoteProperty -Name "HasUCRT" -Value $true
    $result | Add-Member -MemberType NoteProperty -Name "FilePresent" -Value $true
    $result | Add-Member -MemberType NoteProperty -Name "PatchInstalled" -Value "Unknown"
    $result | Add-Member -MemberType NoteProperty -Name "Message" -Value "运行库检测通过"

    $os = Get-OSInfo
    if ($os.OSCode -ne "Win7") {
        # Win10/11 原生内置 UCRT，无需检查
        $result.StatusCode = "ComponentPresent"
        $result.HasUCRT = $true
        $result.Message = "当前操作系统原生内置 Universal C Runtime，无需单独补丁"
        return $result
    }

    # 1. 检测系统核心 DLL 文件存在性 (System32 与 SysWOW64)
    $sys32 = [System.IO.Path]::Combine($env:windir, "System32")
    $ucrtFile1 = [System.IO.Path]::Combine($sys32, "ucrtbase.dll")
    $ucrtFile2 = [System.IO.Path]::Combine($sys32, "api-ms-win-crt-runtime-l1-1-0.dll")
    
    $hasDll = (Test-Path $ucrtFile1) -or (Test-Path $ucrtFile2)
    $result.FilePresent = $hasDll

    # 2. 检测 KB2999226 / KB3118401 补丁安装状态 (通过 CBS 注册表项安全检测，避免 WMI 卡死)
    $patchDetected = $false
    $canCheckPatch = $false
    try {
        $cbsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages"
        if (Test-Path $cbsPath) {
            $canCheckPatch = $true
            $subKeys = Get-ChildItem -Path $cbsPath -ErrorAction SilentlyContinue
            if ($subKeys -ne $null) {
                foreach ($k in $subKeys) {
                    $keyName = [string]$k.PSChildName
                    if ($keyName -like "*KB2999226*" -or $keyName -like "*KB3118401*") {
                        $patchDetected = $true
                        break
                    }
                }
            }
        }
    } catch {
        $canCheckPatch = $false
    }

    if ($patchDetected) {
        $result.PatchInstalled = "Installed"
    } elseif ($canCheckPatch) {
        $result.PatchInstalled = "NotDetected"
    } else {
        $result.PatchInstalled = "CannotCheck"
    }

    # 3. 严格判定三态结果，切勿将 DLL 存在等同于补丁已安装
    if (-not $hasDll -and -not $patchDetected) {
        # 组件完全缺失
        $result.StatusCode = "ComponentMissing"
        $result.HasUCRT = $false
        $result.Message = "【组件缺失】系统缺失 Universal C Runtime 核心库，且未检测到 KB2999226 补丁记录。依赖该运行库的软件将无法运行。"
    } elseif ($hasDll -and $patchDetected) {
        # 组件存在且补丁记录完备
        $result.StatusCode = "ComponentPresent"
        $result.HasUCRT = $true
        $result.Message = "【组件存在】系统已安装 KB2999226/UCRT 补丁且核心运行库 DLL 文件完备。"
    } elseif ($hasDll -and -not $patchDetected) {
        # 无法确认：DLL 虽存在但未见系统级补丁注册
        $result.StatusCode = "Inconclusive"
        $result.HasUCRT = $false
        $result.Message = "【无法确认】检测到 ucrtbase.dll 文件存在，但未检出 KB2999226 补丁注册记录。不能断言系统级运行库已完整安装，需人工核实。"
    } else {
        # 补丁有记录但 DLL 缺失
        $result.StatusCode = "Inconclusive"
        $result.HasUCRT = $false
        $result.Message = "【无法确认】系统存在补丁记录但核心 DLL 文件缺失，运行库状态异常。"
    }

    return $result
}

function Get-FileSha256 {
    <#
    .SYNOPSIS
        计算文件 SHA256 哈希值（兼容 PowerShell 2.0 / .NET 2.0-3.5）
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        return $null
    }

    $fileStream = $null
    try {
        $fileStream = [System.IO.File]::OpenRead($FilePath)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha.ComputeHash($fileStream)
        
        $sb = New-Object System.Text.StringBuilder
        foreach ($b in $hashBytes) {
            [void]$sb.Append($b.ToString("x2"))
        }
        return $sb.ToString().ToLower()
    } catch {
        return $null
    } finally {
        if ($fileStream -ne $null) {
            $fileStream.Close()
            $fileStream.Dispose()
        }
    }
}

function Compare-SoftwareVersion {
    <#
    .SYNOPSIS
        比较两个版本字符串（兼容 PS 2.0）
    .OUTPUTS
        0: 相同版本
        1: 已安装版本 高于 预期版本 (禁止降级)
        -1: 已安装版本 低于 预期版本 (可升级)
        -99: 无法解析或无法对比 (提示人工确认)
    #>
    param(
        [string]$InstalledVersion,
        [string]$TargetVersion
    )

    if ([string]::IsNullOrEmpty($InstalledVersion) -or [string]::IsNullOrEmpty($TargetVersion)) {
        return -99
    }

    $cleanInstalled = $InstalledVersion.Trim()
    $cleanTarget = $TargetVersion.Trim()

    if ($cleanTarget -eq "Latest" -or $cleanTarget -eq "当前兼容版") {
        # 针对标有 Latest 的包，如果已安装则提示人工判断
        return -99
    }

    # 提取只包含数字与点的版本前缀 (例如 "v3.9.8.25-beta" -> "3.9.8.25", "v24" -> "24")
    if ($cleanInstalled -match '(\d+(\.\d+)*)') {
        $cleanInstalled = $matches[1]
    } else {
        return -99
    }

    if ($cleanTarget -match '(\d+(\.\d+)*)') {
        $cleanTarget = $matches[1]
    } else {
        return -99
    }

    $instParts = $cleanInstalled.Split('.')
    $targetParts = $cleanTarget.Split('.')

    $maxLen = [System.Math]::Max($instParts.Length, $targetParts.Length)

    for ($i = 0; $i -lt $maxLen; $i++) {
        [int]$instNum = 0
        [int]$targetNum = 0

        if ($i -lt $instParts.Length) {
            [void][int]::TryParse($instParts[$i], [ref]$instNum)
        }
        if ($i -lt $targetParts.Length) {
            [void][int]::TryParse($targetParts[$i], [ref]$targetNum)
        }

        if ($instNum -gt $targetNum) {
            return 1   # 已安装版本更高
        } elseif ($instNum -lt $targetNum) {
            return -1  # 已安装版本更低
        }
    }

    return 0 # 相同版本
}

function Parse-IniFile {
    <#
    .SYNOPSIS
        解析 INI 配置文件 (保留节定义顺序与字典兼容性)
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    $iniData = @{}
    $sectionOrder = New-Object System.Collections.ArrayList

    if (-not (Test-Path $FilePath)) {
        return $iniData
    }

    $currentSection = ""
    $lines = [System.IO.File]::ReadAllLines($FilePath, [System.Text.Encoding]::UTF8)

    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()
        if ($line -eq "" -or $line.StartsWith(";") -or $line.StartsWith("#")) {
            continue
        }

        if ($line -match '^\[(.*)\]$') {
            $currentSection = $matches[1].Trim()
            if (-not $iniData.ContainsKey($currentSection)) {
                $iniData[$currentSection] = @{}
                [void]$sectionOrder.Add($currentSection)
            }
            continue
        }

        $equalIndex = $line.IndexOf("=")
        if ($equalIndex -gt 0 -and $currentSection -ne "") {
            $key = $line.Substring(0, $equalIndex).Trim()
            $value = $line.Substring($equalIndex + 1).Trim()
            
            if ($value.StartsWith('"') -and $value.EndsWith('"') -and $value.Length -ge 2) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            
            $iniData[$currentSection][$key] = $value
        }
    }

    $iniData["__SectionOrder__"] = $sectionOrder
    return $iniData
}

function Write-AppLog {
    <#
    .SYNOPSIS
        向日志文件和 GUI 回调写入日志
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile = "",
        [scriptblock]$UiCallback = $null
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $formattedLog = "[$timestamp] [$Level] $Message"

    if ($LogFile -ne "") {
        try {
            $logDir = [System.IO.Path]::GetDirectoryName($LogFile)
            if (-not (Test-Path $logDir)) {
                [System.IO.Directory]::CreateDirectory($logDir) | Out-Null
            }
            [System.IO.File]::AppendAllText($LogFile, $formattedLog + [System.Environment]::NewLine, [System.Text.Encoding]::UTF8)
        } catch {
        }
    }

    if ($UiCallback -ne $null) {
        try {
            & $UiCallback $formattedLog
        } catch {
        }
    }
}
