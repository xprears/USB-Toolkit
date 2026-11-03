# =============================================================
# Windows U 盘离线装机助手 - 软件安装与状态校验核心模块
# 严格遵循：
# 1. 软件前置运行库依赖检测（只报不擅自安装补丁）
# 2. 版本状态评估矩阵（未安装/同版本/高版本/低版本/未知）
# 3. 双重校验与「强制重新安装」二次确认控制
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

function Resolve-AppPath {
    param([string]$PathStr)
    if ([string]::IsNullOrEmpty($PathStr)) { return "" }
    return [System.Environment]::ExpandEnvironmentVariables($PathStr)
}

function Test-SoftwareInstalled {
    <#
    .SYNOPSIS
        多维度判断软件是否安装、提取已安装版本，并与安装包版本对比
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Package
    )

    $result = New-Object PSObject
    $result | Add-Member -MemberType NoteProperty -Name "IsInstalled" -Value $false
    $result | Add-Member -MemberType NoteProperty -Name "InstalledVersion" -Value ""
    $result | Add-Member -MemberType NoteProperty -Name "ComparisonCode" -Value "NotInstalled"
    $result | Add-Member -MemberType NoteProperty -Name "StatusSummary" -Value "未安装"
    $result | Add-Member -MemberType NoteProperty -Name "DetailedReason" -Value ""
    $result | Add-Member -MemberType NoteProperty -Name "AllowInstallDefault" -Value $true
    $result | Add-Member -MemberType NoteProperty -Name "CanInstall" -Value $true
    $result | Add-Member -MemberType NoteProperty -Name "PrerequisitesMet" -Value $true
    $result | Add-Member -MemberType NoteProperty -Name "PrerequisiteMessage" -Value ""

    $pkgTargetVersion = $Package["Version"]

    # 1. 前置运行库依赖检查 (如 Win7 下对 UCRT/KB2999226 的依赖)
    if ($Package.ContainsKey("RequireUCRT") -and $Package["RequireUCRT"] -eq "1") {
        $ucrtCheck = Test-Win7UcrtPrerequisite
        if (-not $ucrtCheck.HasUCRT) {
            $result.PrerequisitesMet = $false
            $result.PrerequisiteMessage = $ucrtCheck.Message
        }
    }

    # 2. 检测物理可执行程序及提取文件版本 (支持分号分隔多候选路径)
    $detectedExecPath = ""
    if ($Package.ContainsKey("VerifyExecutable") -and -not [string]::IsNullOrEmpty($Package["VerifyExecutable"])) {
        $candidatePaths = $Package["VerifyExecutable"] -split ';'
        foreach ($cand in $candidatePaths) {
            $candTrim = $cand.Trim()
            if ($candTrim -ne "") {
                $execPath = Resolve-AppPath $candTrim
                if (Test-Path $execPath) {
                    $detectedExecPath = $execPath
                    $result.IsInstalled = $true
                    try {
                        $verInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($execPath)
                        if ($verInfo.FileVersion -ne $null -and "$($verInfo.FileVersion)".Trim() -ne "") {
                            $result.InstalledVersion = "$($verInfo.FileVersion)".Trim()
                        } elseif ($verInfo.ProductVersion -ne $null -and "$($verInfo.ProductVersion)".Trim() -ne "") {
                            $result.InstalledVersion = "$($verInfo.ProductVersion)".Trim()
                        }
                    } catch {
                    }
                    break
                }
            }
        }
    }

    # 3. 若文件未检出或未获版本，检查 Uninstall 注册表项
    if (-not $result.IsInstalled -or [string]::IsNullOrEmpty($result.InstalledVersion)) {
        $uninstallKeys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        $keyword = $Package["Keyword"]
        if ([string]::IsNullOrEmpty($keyword)) { $keyword = $Package["Name"] }

        foreach ($uKey in $uninstallKeys) {
            if (Test-Path $uKey) {
                $subKeys = Get-ChildItem -Path $uKey -ErrorAction SilentlyContinue
                if ($subKeys -ne $null) {
                    foreach ($sub in $subKeys) {
                        $item = Get-ItemProperty -Path $sub.PSPath -ErrorAction SilentlyContinue
                        if ($item -ne $null -and $item.DisplayName -ne $null) {
                            $displayName = [string]$item.DisplayName
                            if ($displayName -like "*$keyword*") {
                                $result.IsInstalled = $true
                                if ($item.DisplayVersion -ne $null -and "$($item.DisplayVersion)".Trim() -ne "") {
                                    $result.InstalledVersion = "$($item.DisplayVersion)".Trim()
                                }
                                break
                            }
                        }
                    }
                }
            }
            if ($result.IsInstalled -and -not [string]::IsNullOrEmpty($result.InstalledVersion)) {
                break
            }
        }
    }

    # 4. 评估版本状态矩阵（严格按照决策要求）
    if (-not $result.IsInstalled) {
        $result.ComparisonCode = "NotInstalled"
        $result.StatusSummary = "未安装"
        $result.DetailedReason = "系统中未检测到该软件"
        $result.AllowInstallDefault = $true
        $result.CanInstall = $true
    } else {
        $instVer = $result.InstalledVersion
        if ([string]::IsNullOrEmpty($instVer)) {
            $result.ComparisonCode = "UnknownVersion"
            $result.StatusSummary = "已安装(版本未知)"
            $result.DetailedReason = "检测到已安装痕迹，但无法精确读取版本号，需人工确认"
            $result.AllowInstallDefault = $false
            $result.CanInstall = $true
        } else {
            $comp = Compare-SoftwareVersion -InstalledVersion $instVer -TargetVersion $pkgTargetVersion
            if ($comp -eq 0) {
                # 相同版本：默认跳过
                $result.ComparisonCode = "SameVersion"
                $result.StatusSummary = "已安装相同版本 (v$instVer)"
                $result.DetailedReason = "本机版本与安装包一致 (v$instVer)，默认跳过"
                $result.AllowInstallDefault = $false
                $result.CanInstall = $false
            } elseif ($comp -eq 1) {
                # 更高版本：跳过，禁止降级
                $result.ComparisonCode = "HigherVersion"
                $result.StatusSummary = "已安装更高版本 (v$instVer)"
                $result.DetailedReason = "本机版本 (v$instVer) 高于待装版本 ($pkgTargetVersion)，禁止自动降级覆盖"
                $result.AllowInstallDefault = $false
                $result.CanInstall = $false
            } elseif ($comp -eq -1) {
                # 较低版本：提示可升级，默认不执行
                $result.ComparisonCode = "LowerVersion"
                $result.StatusSummary = "已安装低版本 (v$instVer, 可升级)"
                $result.DetailedReason = "本机版本 (v$instVer) 低于待装版本 ($pkgTargetVersion)，可升级，默认不自动执行"
                $result.AllowInstallDefault = $false
                $result.CanInstall = $true
            } else {
                # 无法解析版本：人工确认
                $result.ComparisonCode = "UnknownVersion"
                $result.StatusSummary = "已安装 v$instVer (需人工确认)"
                $result.DetailedReason = "版本格式非标，无法确定升级关系，需人工确认"
                $result.AllowInstallDefault = $false
                $result.CanInstall = $true
            }
        }
    }

    # 若前置依赖不满足，封锁安装
    if (-not $result.PrerequisitesMet) {
        $result.CanInstall = $false
        $result.AllowInstallDefault = $false
        $result.StatusSummary = "前置依赖缺失 (无法安装)"
        $result.DetailedReason = $result.PrerequisiteMessage
    }

    return $result
}

function Test-PackageIntegrity {
    <#
    .SYNOPSIS
        检验 U 盘中的安装包文件是否存在及 SHA256 完整性
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Package,
        [Parameter(Mandatory=$true)]
        [string]$UsbRoot
    )

    $result = New-Object PSObject
    $result | Add-Member -MemberType NoteProperty -Name "Status" -Value "OK"
    $result | Add-Member -MemberType NoteProperty -Name "Message" -Value "文件就绪"
    $result | Add-Member -MemberType NoteProperty -Name "FullPath" -Value ""
    $result | Add-Member -MemberType NoteProperty -Name "FileExists" -Value $false
    $result | Add-Member -MemberType NoteProperty -Name "ActualSha256" -Value ""

    $relPath = $Package["PackagePath"]
    $fullPath = [System.IO.Path]::Combine($UsbRoot, $relPath)
    $result.FullPath = $fullPath

    if (-not (Test-Path $fullPath)) {
        # 兼容扩展名变体 (例如同时支持 .exe 或 .msi 企业包)
        $altFullPath = ""
        if ($fullPath.ToLower().EndsWith(".exe")) {
            $altFullPath = [System.IO.Path]::ChangeExtension($fullPath, ".msi")
        } elseif ($fullPath.ToLower().EndsWith(".msi")) {
            $altFullPath = [System.IO.Path]::ChangeExtension($fullPath, ".exe")
        }
        if ($altFullPath -ne "" -and (Test-Path $altFullPath)) {
            $fullPath = $altFullPath
            $result.FullPath = $fullPath
        } else {
            $result.Status = "Missing"
            $result.FileExists = $false
            $result.Message = "安装包不存在: $relPath"
            return $result
        }
    }

    $result.FileExists = $true

    $expectedSha = $Package["SHA256"]
    if (-not [string]::IsNullOrEmpty($expectedSha)) {
        $actualSha = Get-FileSha256 -FilePath $fullPath
        $result.ActualSha256 = $actualSha
        if ($actualSha -ne $expectedSha.ToLower().Trim()) {
            $result.Status = "HashMismatch"
            $result.Message = "SHA256 校验不匹配! 预期: $expectedSha, 实际: $actualSha"
            return $result
        }
    }

    return $result
}

function Invoke-SoftwareInstall {
    <#
    .SYNOPSIS
        执行单款软件的静默安装与后置校验
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Package,
        [Parameter(Mandatory=$true)]
        [string]$UsbRoot,
        [bool]$ForceReinstall = $false,
        [int]$TimeoutSeconds = 300,
        [string]$LogFile = "",
        [scriptblock]$UiCallback = $null
    )

    $name = $Package["Name"]
    Write-AppLog -Message "--------------------------------------------------" -Level "INFO" -LogFile $LogFile -UiCallback $UiCallback
    Write-AppLog -Message "开始处理软件: $name" -Level "INFO" -LogFile $LogFile -UiCallback $UiCallback

    $installResult = New-Object PSObject
    $installResult | Add-Member -MemberType NoteProperty -Name "Success" -Value $false
    $installResult | Add-Member -MemberType NoteProperty -Name "Skipped" -Value $false
    $installResult | Add-Member -MemberType NoteProperty -Name "ExitCode" -Value -1
    $installResult | Add-Member -MemberType NoteProperty -Name "Message" -Value ""

    # 1. 前置运行库依赖检查
    if ($Package.ContainsKey("RequireUCRT") -and $Package["RequireUCRT"] -eq "1") {
        $ucrtCheck = Test-Win7UcrtPrerequisite
        if (-not $ucrtCheck.HasUCRT) {
            $installResult.Message = $ucrtCheck.Message
            Write-AppLog -Message "[$name] 阻止安装: $($ucrtCheck.Message)" -Level "ERROR" -LogFile $LogFile -UiCallback $UiCallback
            return $installResult
        }
    }

    # 2. 安装包文件存在与完整性检查
    $integrity = Test-PackageIntegrity -Package $Package -UsbRoot $UsbRoot
    if ($integrity.Status -ne "OK") {
        $installResult.Message = $integrity.Message
        Write-AppLog -Message "[$name] 完整性检查失败: $($integrity.Message)" -Level "ERROR" -LogFile $LogFile -UiCallback $UiCallback
        return $installResult
    }

    # 3. 安装前版本检查与拦截
    $checkBefore = Test-SoftwareInstalled -Package $Package
    if ($checkBefore.IsInstalled) {
        Write-AppLog -Message "[$name] 安装前检测: $($checkBefore.DetailedReason)" -Level "WARN" -LogFile $LogFile -UiCallback $UiCallback
        
        if (-not $ForceReinstall) {
            if ($checkBefore.ComparisonCode -eq "SameVersion") {
                $installResult.Skipped = $true
                $installResult.Message = "已安装相同版本，默认跳过安装"
                Write-AppLog -Message "[$name] $($installResult.Message)" -Level "INFO" -LogFile $LogFile -UiCallback $UiCallback
                return $installResult
            } elseif ($checkBefore.ComparisonCode -eq "HigherVersion") {
                $installResult.Skipped = $true
                $installResult.Message = "已安装更高版本，禁止自动降级覆盖"
                Write-AppLog -Message "[$name] $($installResult.Message)" -Level "WARN" -LogFile $LogFile -UiCallback $UiCallback
                return $installResult
            }
        } else {
            Write-AppLog -Message "[$name] 警告: 用户已启用【强制重新安装】模式，将执行覆盖安装" -Level "WARN" -LogFile $LogFile -UiCallback $UiCallback
        }
    }

    # 4. 准备启动安装进程
    $installerPath = $integrity.FullPath
    $silentArgs = $Package["SilentArgs"]
    Write-AppLog -Message "[$name] 执行路径: $installerPath" -Level "INFO" -LogFile $LogFile -UiCallback $UiCallback
    Write-AppLog -Message "[$name] 静默参数: $silentArgs" -Level "INFO" -LogFile $LogFile -UiCallback $UiCallback

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    if ($installerPath.ToLower().EndsWith(".msi")) {
        $pinfo.FileName = "msiexec.exe"
        $msiArgs = "/i `"$installerPath`""
        if (-not [string]::IsNullOrEmpty($silentArgs)) {
            $msiArgs += " $silentArgs"
        } else {
            $msiArgs += " /qn /norestart"
        }
        $pinfo.Arguments = $msiArgs
    } else {
        $pinfo.FileName = $installerPath
        $pinfo.Arguments = $silentArgs
    }
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $pinfo.WorkingDirectory = [System.IO.Path]::GetDirectoryName($installerPath)

    try {
        $process = [System.Diagnostics.Process]::Start($pinfo)
        if ($process -eq $null) {
            $installResult.Message = "无法启动安装程序进程"
            Write-AppLog -Message "[$name] 无法启动安装程序进程" -Level "ERROR" -LogFile $LogFile -UiCallback $UiCallback
            return $installResult
        }

        # 超时监控
        $hasExited = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $hasExited) {
            try { $process.Kill() } catch {}
            $installResult.Message = "安装超时 (超过 $TimeoutSeconds 秒) 已强行终止"
            Write-AppLog -Message "[$name] $($installResult.Message)" -Level "ERROR" -LogFile $LogFile -UiCallback $UiCallback
            return $installResult
        }

        $exitCode = $process.ExitCode
        $installResult.ExitCode = $exitCode
        Write-AppLog -Message "[$name] 安装进程已退出，退出码: $exitCode" -Level "INFO" -LogFile $LogFile -UiCallback $UiCallback

    } catch {
        $installResult.Message = "执行安装异常: $($_.Exception.Message)"
        Write-AppLog -Message "[$name] $($installResult.Message)" -Level "ERROR" -LogFile $LogFile -UiCallback $UiCallback
        return $installResult
    }

    # 5. 退出码初筛
    $exitCodeOk = ($exitCode -eq 0 -or $exitCode -eq 3010)
    if (-not $exitCodeOk) {
        Write-AppLog -Message "[$name] 安装进程返回非零退出码: $exitCode" -Level "WARN" -LogFile $LogFile -UiCallback $UiCallback
    }

    # 6. 后置物理验证（必须验证实际物理程序存在）
    # 针对 Chrome 等采用引导释放器 (Bootstrapper) 异步拉起后台 setup.exe 的软件包，
    # 外层引导进程退出码返回 0 时，后台释放与注册表写入可能仍在进行中。
    # 采用智能轮询等待机制（最高 45 秒，每 2 秒重试检测一次），确保文件完全落盘或注册表生效。
    $checkAfter = $null
    $maxWaitSec = 45
    $pollIntervalSec = 2
    $elapsedSec = 0
    $hasWaitedBg = $false

    Write-AppLog -Message "[$name] 正在执行安装结果实体校验..." -Level "INFO" -LogFile $LogFile -UiCallback $UiCallback

    while ($elapsedSec -lt $maxWaitSec) {
        [System.Threading.Thread]::Sleep($pollIntervalSec * 1000)
        $elapsedSec += $pollIntervalSec

        $checkAfter = Test-SoftwareInstalled -Package $Package
        if ($checkAfter.IsInstalled) {
            break
        }

        # 检测是否有已知的安装/释放后台进程在运行 (如 setup.exe, GoogleUpdate.exe)
        $bgProcesses = @(Get-Process -Name "setup", "GoogleUpdate", "Installer" -ErrorAction SilentlyContinue)
        if ($bgProcesses.Count -gt 0) {
            if (-not $hasWaitedBg -or ($elapsedSec % 10 -eq 0)) {
                Write-AppLog -Message "[$name] 检测到后台安装释放进程仍在运行，持续等待落盘中 (${elapsedSec}/${maxWaitSec}s)..." -Level "INFO" -LogFile $LogFile -UiCallback $UiCallback
                $hasWaitedBg = $true
            }
        }
    }

    if ($checkAfter -ne $null -and $checkAfter.IsInstalled) {
        $installResult.Success = $true
        $newVer = $checkAfter.InstalledVersion
        if ([string]::IsNullOrEmpty($newVer)) { $newVer = "已就绪" }
        if ($exitCode -eq 3010) {
            $installResult.Message = "安装成功 (版本: $newVer，系统提示需重启)"
        } else {
            $installResult.Message = "安装成功并通过实体校验 (版本: $newVer)"
        }
        Write-AppLog -Message "[$name] $($installResult.Message)" -Level "SUCCESS" -LogFile $LogFile -UiCallback $UiCallback
    } else {
        $installResult.Success = $false
        $installResult.Message = "后置校验失败: 目标文件或注册表条目不存在，安装未生效 (等待 ${elapsedSec}s 超时)"
        Write-AppLog -Message "[$name] $($installResult.Message)" -Level "ERROR" -LogFile $LogFile -UiCallback $UiCallback
    }

    return $installResult
}
