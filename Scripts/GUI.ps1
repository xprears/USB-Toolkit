# =============================================================
# Windows U 盘离线装机助手 - 图形界面交互主程序 (第二阶段增强版)
# 严格遵循：
# 1. 软件前置依赖阻断（如缺少 UCRT）
# 2. 版本状态评估矩阵（未安装/同版本跳过/高版本防降级/低版本升级提示/未知确认）
# 3. 「强制重新安装」二次弹窗确认保护机制
# =============================================================

param(
    [string]$UsbRoot = ""
)

# 确保在 STA (单线程套间) 模式下运行 (Windows 7 / PowerShell 2.0 运行 WinForms 必须)
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    $myPath = $MyInvocation.MyCommand.Definition
    if (-not $myPath) { $myPath = $MyInvocation.MyCommand.Path }
    if ($myPath -and (Test-Path $myPath)) {
        $argList = @("-sta", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$myPath`"")
        if ($UsbRoot) { $argList += @("-UsbRoot", "`"$UsbRoot`"") }
        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argList -PassThru -Wait
        exit $proc.ExitCode
    }
}

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
} catch {
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
}

$scriptDir = ""
if ($PSScriptRoot) {
    $scriptDir = $PSScriptRoot
} elseif ($MyInvocation.MyCommand.Path) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} elseif ($MyInvocation.MyCommand.Definition -and (Test-Path $MyInvocation.MyCommand.Definition)) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

if ([string]::IsNullOrEmpty($scriptDir) -or (-not (Test-Path (Join-Path $scriptDir "Utils.ps1")))) {
    if (-not [string]::IsNullOrEmpty($UsbRoot) -and (Test-Path (Join-Path $UsbRoot "Scripts\Utils.ps1"))) {
        $scriptDir = Join-Path $UsbRoot "Scripts"
    } elseif (Test-Path ".\Scripts\Utils.ps1") {
        $scriptDir = (Get-Item ".\Scripts").FullName
    } elseif (Test-Path ".\Utils.ps1") {
        $scriptDir = (Get-Item ".").FullName
    }
}

if ([string]::IsNullOrEmpty($UsbRoot) -or (-not (Test-Path $UsbRoot))) {
    if ($scriptDir -and (Test-Path $scriptDir)) {
        $UsbRoot = Split-Path -Parent $scriptDir
    }
}
if ($UsbRoot -match '^[A-Za-z]:$') {
    $UsbRoot = $UsbRoot + "\"
}
try {
    $UsbRoot = (Get-Item -LiteralPath $UsbRoot).FullName
} catch {
    if ($scriptDir) { $UsbRoot = Split-Path -Parent $scriptDir }
}

. ([System.IO.Path]::Combine($scriptDir, "Utils.ps1"))
. ([System.IO.Path]::Combine($scriptDir, "Installer.ps1"))
. ([System.IO.Path]::Combine($scriptDir, "Updater.ps1"))

[System.Windows.Forms.Application]::EnableVisualStyles()

# -------------------------------------------------------------
# 初始化配置与日志路径
# -------------------------------------------------------------
$configPath = [System.IO.Path]::Combine($UsbRoot, "Config\config.ini")
$packagesPath = [System.IO.Path]::Combine($UsbRoot, "Config\packages.ini")
$logsDir = [System.IO.Path]::Combine($UsbRoot, "Logs")
$isReadOnlyMedia = $false

# 检查当前介质是否可写 (兼容只读 ISO 光盘挂载或写保护 U 盘)
try {
    if (-not (Test-Path $logsDir)) {
        [System.IO.Directory]::CreateDirectory($logsDir) | Out-Null
    }
    $testFile = [System.IO.Path]::Combine($logsDir, ".write_test_" + [System.Guid]::NewGuid().ToString("N"))
    [System.IO.File]::WriteAllText($testFile, "test")
    if (Test-Path $testFile) {
        [System.IO.File]::Delete($testFile)
    }
} catch {
    $isReadOnlyMedia = $true
}

if ($isReadOnlyMedia) {
    # 只读介质降级：自动重定向至本地临时目录 %TEMP%\USB-Toolkit\Logs
    $tempBase = [System.Environment]::GetEnvironmentVariable("TEMP")
    if ([string]::IsNullOrEmpty($tempBase)) {
        $tempBase = "C:\Windows\Temp"
    }
    $logsDir = [System.IO.Path]::Combine($tempBase, "USB-Toolkit\Logs")
    if (-not (Test-Path $logsDir)) {
        [System.IO.Directory]::CreateDirectory($logsDir) | Out-Null
    }
}

$logFileName = "Install_" + (Get-Date).ToString("yyyyMMdd_HHmmss") + ".log"
$currentLogFile = [System.IO.Path]::Combine($logsDir, $logFileName)

$appConfig = Parse-IniFile -FilePath $configPath
$packagesConfig = Parse-IniFile -FilePath $packagesPath

$appTitle = "Windows U 盘离线装机助手"
if ($appConfig.ContainsKey("App") -and $appConfig["App"].ContainsKey("Title")) {
    $appTitle = $appConfig["App"]["Title"]
}

$osInfo = Get-OSInfo
$isOnline = Test-NetworkOnline

# 启动时立即建立日志
Write-AppLog -Message "==================================================" -Level "INFO" -LogFile $currentLogFile
Write-AppLog -Message "Windows U 盘离线装机助手已启动" -Level "INFO" -LogFile $currentLogFile
Write-AppLog -Message "程序根目录: $UsbRoot" -Level "INFO" -LogFile $currentLogFile
if ($isReadOnlyMedia) {
    Write-AppLog -Message "检测到当前处于只读介质 (ISO/光盘)，日志自动重定向至: $logsDir" -Level "INFO" -LogFile $currentLogFile
}
Write-AppLog -Message "检测系统环境: $($osInfo.DisplaySummary)" -Level "INFO" -LogFile $currentLogFile

# -------------------------------------------------------------
# 构建主窗体
# -------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "$appTitle v1.2.0 (第二阶段)"
$form.Size = New-Object System.Drawing.Size(960, 700)
$form.MinimumSize = New-Object System.Drawing.Size(880, 620)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(246, 248, 250)

# -------------------------------------------------------------
# 顶部看板 (系统与环境信息)
# -------------------------------------------------------------
$topPanel = New-Object System.Windows.Forms.Panel
$topPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$topPanel.Height = 92
$topPanel.BackColor = [System.Drawing.Color]::White
$topPanel.Padding = New-Object System.Windows.Forms.Padding(16, 8, 16, 8)

$lblOsTitle = New-Object System.Windows.Forms.Label
$lblOsTitle.Text = "目标操作系统:"
$lblOsTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9, [System.Drawing.FontStyle]::Bold)
$lblOsTitle.Location = New-Object System.Drawing.Point(16, 12)
$lblOsTitle.AutoSize = $true
$topPanel.Controls.Add($lblOsTitle)

$lblOsVal = New-Object System.Windows.Forms.Label
$lblOsVal.Text = $osInfo.DisplaySummary
if ($osInfo.IsSupported) {
    $lblOsVal.ForeColor = [System.Drawing.Color]::FromArgb(24, 134, 45)
} else {
    $lblOsVal.ForeColor = [System.Drawing.Color]::FromArgb(207, 34, 46)
    $lblOsVal.Text += " [注意: 未经认证的环境]"
}
$lblOsVal.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9.5, [System.Drawing.FontStyle]::Bold)
$lblOsVal.Location = New-Object System.Drawing.Point(115, 12)
$lblOsVal.AutoSize = $true
$topPanel.Controls.Add($lblOsVal)

$lblNetTitle = New-Object System.Windows.Forms.Label
$lblNetTitle.Text = "网络连接状态:"
$lblNetTitle.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9, [System.Drawing.FontStyle]::Bold)
$lblNetTitle.Location = New-Object System.Drawing.Point(16, 38)
$lblNetTitle.AutoSize = $true
$topPanel.Controls.Add($lblNetTitle)

$lblNetVal = New-Object System.Windows.Forms.Label
if ($isOnline) {
    $lblNetVal.Text = "在线联机 (可执行版本与签名检查)"
    $lblNetVal.ForeColor = [System.Drawing.Color]::FromArgb(9, 105, 218)
} else {
    $lblNetVal.Text = "离线环境 (离线安装优先模式运行中)"
    $lblNetVal.ForeColor = [System.Drawing.Color]::FromArgb(101, 109, 118)
}
$lblNetVal.Location = New-Object System.Drawing.Point(115, 38)
$lblNetVal.AutoSize = $true
$topPanel.Controls.Add($lblNetVal)

$lblUsbTitle = New-Object System.Windows.Forms.Label
$lblUsbTitle.Text = "U盘工作路径: $UsbRoot"
$lblUsbTitle.ForeColor = [System.Drawing.Color]::FromArgb(87, 96, 106)
$lblUsbTitle.Location = New-Object System.Drawing.Point(16, 64)
$lblUsbTitle.AutoSize = $true
$topPanel.Controls.Add($lblUsbTitle)

# -------------------------------------------------------------
# 顶部工具栏 (快速勾选与强制选项)
# -------------------------------------------------------------
$toolBarPanel = New-Object System.Windows.Forms.Panel
$toolBarPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$toolBarPanel.Height = 44
$toolBarPanel.BackColor = [System.Drawing.Color]::FromArgb(246, 248, 250)
$toolBarPanel.Padding = New-Object System.Windows.Forms.Padding(16, 6, 16, 6)

$toolBar = New-Object System.Windows.Forms.FlowLayoutPanel
$toolBar.Dock = [System.Windows.Forms.DockStyle]::Fill
$toolBar.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$toolBar.WrapContents = $false

$btnSelectAll = New-Object System.Windows.Forms.Button
$btnSelectAll.Text = "全选"
$btnSelectAll.Size = New-Object System.Drawing.Size(70, 30)
$btnSelectAll.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
$toolBar.Controls.Add($btnSelectAll)

$btnDeselectAll = New-Object System.Windows.Forms.Button
$btnDeselectAll.Text = "全不选"
$btnDeselectAll.Size = New-Object System.Drawing.Size(70, 30)
$btnDeselectAll.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
$toolBar.Controls.Add($btnDeselectAll)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "刷新状态"
$btnRefresh.Size = New-Object System.Drawing.Size(85, 30)
$btnRefresh.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
$toolBar.Controls.Add($btnRefresh)

$btnCheckUpdate = New-Object System.Windows.Forms.Button
$btnCheckUpdate.Text = "检查在线更新"
$btnCheckUpdate.Size = New-Object System.Drawing.Size(105, 30)
$btnCheckUpdate.Margin = New-Object System.Windows.Forms.Padding(0, 0, 16, 0)
$toolBar.Controls.Add($btnCheckUpdate)

# 独立的「强制重新安装」复选框
$chkForceReinstall = New-Object System.Windows.Forms.CheckBox
$chkForceReinstall.Text = "强制重新安装/覆盖 (需二次确认)"
$chkForceReinstall.ForeColor = [System.Drawing.Color]::FromArgb(180, 50, 20)
$chkForceReinstall.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9, [System.Drawing.FontStyle]::Bold)
$chkForceReinstall.AutoSize = $true
$chkForceReinstall.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 0)
$toolBar.Controls.Add($chkForceReinstall)

$toolBarPanel.Controls.Add($toolBar)

# -------------------------------------------------------------
# 底部控制区：进度条、操作按钮与日志 (Dock = Bottom)
# -------------------------------------------------------------
$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
$bottomPanel.Height = 220
$bottomPanel.BackColor = [System.Drawing.Color]::White
$bottomPanel.Padding = New-Object System.Windows.Forms.Padding(16, 8, 16, 10)

# 1. 进度条
$pbarPanel = New-Object System.Windows.Forms.Panel
$pbarPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$pbarPanel.Height = 22
$pbarPanel.Padding = New-Object System.Windows.Forms.Padding(0, 2, 0, 4)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Dock = [System.Windows.Forms.DockStyle]::Fill
$pbarPanel.Controls.Add($progressBar)
$bottomPanel.Controls.Add($pbarPanel)

# 2. 状态信息与操作按钮栏 (左右自适应布局，杜绝 DPI 缩放丢失)
$actionPanel = New-Object System.Windows.Forms.Panel
$actionPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$actionPanel.Height = 44
$actionPanel.Padding = New-Object System.Windows.Forms.Padding(0, 4, 0, 4)

$lblStats = New-Object System.Windows.Forms.Label
$lblStats.Text = "就绪 | 当前系统适用: 0 款 | 已勾选待安装: 0 款"
$lblStats.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9.5, [System.Drawing.FontStyle]::Bold)
$lblStats.Dock = [System.Windows.Forms.DockStyle]::Left
$lblStats.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$lblStats.AutoSize = $true
$actionPanel.Controls.Add($lblStats)

$btnContainer = New-Object System.Windows.Forms.FlowLayoutPanel
$btnContainer.Dock = [System.Windows.Forms.DockStyle]::Right
$btnContainer.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
$btnContainer.AutoSize = $true
$btnContainer.WrapContents = $false

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "开始批量安装 (下一步)"
$btnInstall.Size = New-Object System.Drawing.Size(165, 34)
$btnInstall.BackColor = [System.Drawing.Color]::FromArgb(31, 136, 61)
$btnInstall.ForeColor = [System.Drawing.Color]::White
$btnInstall.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnInstall.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9.5, [System.Drawing.FontStyle]::Bold)
$btnInstall.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnInstall.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
$btnContainer.Controls.Add($btnInstall)

$btnViewLog = New-Object System.Windows.Forms.Button
$btnViewLog.Text = "查看完整日志"
$btnViewLog.Size = New-Object System.Drawing.Size(110, 34)
$btnViewLog.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)
$btnContainer.Controls.Add($btnViewLog)

$actionPanel.Controls.Add($btnContainer)
$bottomPanel.Controls.Add($actionPanel)

# 3. 日志文本框 (Dock = Fill)
$logPanel = New-Object System.Windows.Forms.Panel
$logPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$logPanel.Padding = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Dock = [System.Windows.Forms.DockStyle]::Fill
$txtLog.Multiline = $true
$txtLog.ReadOnly = $true
$txtLog.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)
$logPanel.Controls.Add($txtLog)

$bottomPanel.Controls.Add($logPanel)

# 确保 bottomPanel 内部层次
$pbarPanel.SendToBack()
$actionPanel.SendToBack()
$logPanel.BringToFront()

# -------------------------------------------------------------
# 中间核心区域：软件清单列表 (Dock = Fill)
# -------------------------------------------------------------
$listPanel = New-Object System.Windows.Forms.Panel
$listPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$listPanel.Padding = New-Object System.Windows.Forms.Padding(16, 2, 16, 6)

$listView = New-Object System.Windows.Forms.ListView
$listView.Dock = [System.Windows.Forms.DockStyle]::Fill
$listView.View = [System.Windows.Forms.View]::Details
$listView.CheckBoxes = $true
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.MultiSelect = $false

[void]$listView.Columns.Add("软件名称", 190)
[void]$listView.Columns.Add("分类", 75)
[void]$listView.Columns.Add("安装包状态", 90)
[void]$listView.Columns.Add("本机状态与版本判断", 220)
[void]$listView.Columns.Add("目标版本", 90)
[void]$listView.Columns.Add("配置说明与验证状态", 260)

$listPanel.Controls.Add($listView)

# -------------------------------------------------------------
# 将各区域添加至主窗体，并严格锁定 Docking 与 Z-Order
# -------------------------------------------------------------
$form.Controls.Add($listPanel)
$form.Controls.Add($bottomPanel)
$form.Controls.Add($toolBarPanel)
$form.Controls.Add($topPanel)

$topPanel.SendToBack()
$toolBarPanel.SendToBack()
$bottomPanel.SendToBack()
$listPanel.BringToFront()

# -------------------------------------------------------------
# 业务逻辑与事件
# -------------------------------------------------------------
$script:LogWriter = {
    param([string]$line)
    if ($txtLog.IsDisposed) { return }
    $txtLog.AppendText($line + "`r`n")
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

$script:IsReloading = $false

function Reload-PackageList {
    $script:IsReloading = $true
    $listView.Items.Clear()
    
    $targetOS = $osInfo.OSCode
    Write-AppLog -Message "正在检索适用 [$targetOS] 的软件包清单..." -Level "INFO" -LogFile $currentLogFile -UiCallback $script:LogWriter

    $sections = if ($packagesConfig.ContainsKey("__SectionOrder__")) {
        $packagesConfig["__SectionOrder__"]
    } else {
        $packagesConfig.Keys
    }

    foreach ($secKey in $sections) {
        if ($secKey -eq "__SectionOrder__") { continue }
        $pkg = $packagesConfig[$secKey]
        $pkg["Key"] = $secKey

        # 1. 过滤操作系统版本适用性 (Win7, Win10, Win11)
        $supportedOSList = @()
        if ($pkg.ContainsKey("OS")) {
            $supportedOSList = ($pkg["OS"] -split ',') | ForEach-Object { $_.Trim() }
        }
        if (-not ($supportedOSList -contains $targetOS)) {
            continue
        }

        # 2. 过滤硬件 CPU 架构适用性 (x64, ARM64, x86)
        $targetArch = $osInfo.Arch
        if ($pkg.ContainsKey("Arch") -and -not [string]::IsNullOrEmpty($pkg["Arch"])) {
            $supportedArchList = ($pkg["Arch"] -split ',') | ForEach-Object { $_.Trim() }
            if (-not ($supportedArchList -contains $targetArch)) {
                continue
            }
        }

        # 2. 检查安装包文件完整性
        $integrity = Test-PackageIntegrity -Package $pkg -UsbRoot $UsbRoot
        $integrityText = "正常就绪"
        if ($integrity.Status -eq "Missing") {
            $integrityText = "文件缺失"
        } elseif ($integrity.Status -eq "HashMismatch") {
            $integrityText = "哈希异常"
        }

        # 3. 检查本机实际安装情况及版本关系
        $installState = Test-SoftwareInstalled -Package $pkg

        # 4. 界面展示构建
        $item = New-Object System.Windows.Forms.ListViewItem($pkg["Name"])
        [void]$item.SubItems.Add($pkg["Category"])
        [void]$item.SubItems.Add($integrityText)
        [void]$item.SubItems.Add($installState.StatusSummary)
        [void]$item.SubItems.Add($pkg["Version"])
        [void]$item.SubItems.Add($pkg["Description"])
        $item.Tag = @{
            Package = $pkg;
            InstallState = $installState;
            Integrity = $integrity
        }

        # 5. 严格执行用户决策的勾选规则 (未测试软件严禁默认自动勾选)
        $shouldCheck = $false
        $isUntested = ($pkg.ContainsKey("Status") -and ($pkg["Status"] -eq "Untested" -or $pkg["Status"] -eq "PendingVerification"))

        if ($installState.PrerequisitesMet -and $integrity.Status -eq "OK" -and -not $isUntested) {
            if ($installState.ComparisonCode -eq "NotInstalled") {
                $shouldCheck = ($pkg["DefaultSelected"] -eq "1")
            } elseif ($installState.ComparisonCode -eq "LowerVersion") {
                # 检测到低版本：提示可升级，默认不执行
                $shouldCheck = $false
            } elseif ($installState.ComparisonCode -eq "SameVersion" -or $installState.ComparisonCode -eq "HigherVersion") {
                # 同版本或高版本：默认跳过
                $shouldCheck = $false
            }
        }

        $item.Checked = $shouldCheck

        # 颜色区分
        if (-not $installState.PrerequisitesMet) {
            $item.ForeColor = [System.Drawing.Color]::FromArgb(207, 34, 46) # 依赖缺失红字
        } elseif ($integrity.Status -ne "OK") {
            $item.ForeColor = [System.Drawing.Color]::FromArgb(120, 120, 120) # 文件缺失灰色
        } elseif ($installState.ComparisonCode -eq "HigherVersion") {
            $item.ForeColor = [System.Drawing.Color]::FromArgb(140, 80, 0)   # 避免降级暗橙
        } elseif ($installState.ComparisonCode -eq "SameVersion") {
            $item.ForeColor = [System.Drawing.Color]::FromArgb(60, 120, 60)   # 已是同版本淡绿
        }

        [void]$listView.Items.Add($item)
    }

    $script:IsReloading = $false
    Update-SummaryStats
    $totalLoaded = $listView.Items.Count
    Write-AppLog -Message "适用软件列表检索就绪，当前系统共加载 $totalLoaded 款软件包。" -Level "INFO" -LogFile $currentLogFile -UiCallback $script:LogWriter
}

function Update-SummaryStats {
    $total = $listView.Items.Count
    $checkedCount = 0
    foreach ($item in $listView.Items) {
        if ($item.Checked) { $checkedCount++ }
    }
    $lblStats.Text = "就绪 | 当前系统适用: $total 款 | 已勾选待安装: $checkedCount 款 (确认勾选后请点击右侧按钮开始安装)"
}

# 勾选变化时的事先校验拦截
$listView.Add_ItemCheck({
    param($sender, $e)
    if ($script:IsReloading) { return }

    $item = $listView.Items[$e.Index]
    $data = $item.Tag
    $pkg = $data["Package"]
    $inst = $data["InstallState"]
    $integ = $data["Integrity"]

    # 用户试图手动勾选
    if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) {
        # 1. 拦截前置依赖缺失 (如 Win7 缺少 UCRT)
        if (-not $inst.PrerequisitesMet) {
            [System.Windows.Forms.MessageBox]::Show("无法勾选安装 [$($pkg['Name'])]：`r`n$($inst.PrerequisiteMessage)`r`n`r`n系统缺少基础前置运行库，工具不会擅自安装补丁，请先在系统中补齐后重试。", "前置依赖缺失拦截", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Stop)
            $e.NewValue = [System.Windows.Forms.CheckState]::Unchecked
            return
        }

        # 2. 拦截安装包物理缺失
        if ($integ.Status -ne "OK") {
            [System.Windows.Forms.MessageBox]::Show("无法勾选安装 [$($pkg['Name'])]：`r`n$($integ.Message)`r`n`r`n请先将正确的官方安装包放入 U 盘指定目录。", "安装包缺失", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            $e.NewValue = [System.Windows.Forms.CheckState]::Unchecked
            return
        }

        # 3. 拦截高版本防降级（在未启用强制重新安装时）
        if ($inst.ComparisonCode -eq "HigherVersion" -and -not $chkForceReinstall.Checked) {
            [System.Windows.Forms.MessageBox]::Show("检测到当前系统已安装更高版本 ($($inst.InstalledVersion))！`r`n按安全策略禁止自动降级安装。`r`n`r`n若确实需要强行覆盖，请先在顶部勾选【强制重新安装/覆盖】选项。", "禁止降级安装", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            $e.NewValue = [System.Windows.Forms.CheckState]::Unchecked
            return
        }

        # 4. 同版本防重装提示（在未启用强制重新安装时）
        if ($inst.ComparisonCode -eq "SameVersion" -and -not $chkForceReinstall.Checked) {
            [System.Windows.Forms.MessageBox]::Show("检测到当前系统已存在相同版本 ($($inst.InstalledVersion))。`r`n按默认策略将跳过重复安装。`r`n`r`n若确需强行重装，请先勾选顶部的【强制重新安装/覆盖】。", "已是相同版本", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            $e.NewValue = [System.Windows.Forms.CheckState]::Unchecked
            return
        }
    }
})

$listView.Add_ItemChecked({
    if (-not $script:IsReloading) {
        Update-SummaryStats
    }
})

$btnSelectAll.Add_Click({
    foreach ($item in $listView.Items) {
        $data = $item.Tag
        $inst = $data["InstallState"]
        $integ = $data["Integrity"]
        # 仅全选满足安全安装条件的项
        if ($inst.PrerequisitesMet -and $integ.Status -eq "OK") {
            if ($chkForceReinstall.Checked -or ($inst.ComparisonCode -ne "HigherVersion" -and $inst.ComparisonCode -ne "SameVersion")) {
                $item.Checked = $true
            }
        }
    }
    Update-SummaryStats
})

$btnDeselectAll.Add_Click({
    foreach ($item in $listView.Items) {
        $item.Checked = $false
    }
    Update-SummaryStats
})

$btnRefresh.Add_Click({
    Reload-PackageList
})

$btnCheckUpdate.Add_Click({
    $remoteUrl = ""
    if ($appConfig.ContainsKey("Update") -and $appConfig["Update"].ContainsKey("ManifestUrl")) {
        $remoteUrl = $appConfig["Update"]["ManifestUrl"]
    }
    
    $upRes = Check-OnlinePackageUpdates -UsbRoot $UsbRoot -RemoteManifestUrl $remoteUrl -LogCallback $script:LogWriter
    if (-not $upRes.IsOnline) {
        [System.Windows.Forms.MessageBox]::Show("当前处于全离线环境：`r`n`r`n装机助手已启用全离线优先模式，无网络也能完整执行所有安装，无需进行在线更新。", "离线运行模式", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } elseif ($upRes.HasUpdates) {
        $msg = "检测到有可更新的离线软件包：`r`n`r`n"
        foreach ($u in $upRes.UpdateList) {
            $msg += "• $($u.Name): 当前 v$($u.LocalVersion) -> 远端 v$($u.RemoteVersion)`r`n"
        }
        $msg += "`r`n建议在有网的维护电脑上下载新版放入 Packages 目录。"
        [System.Windows.Forms.MessageBox]::Show($msg, "发现新版本", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } else {
        [System.Windows.Forms.MessageBox]::Show($upRes.Message, "检查更新", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

$btnViewLog.Add_Click({
    if (Test-Path $currentLogFile) {
        [System.Diagnostics.Process]::Start("notepad.exe", "`"$currentLogFile`"") | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show("暂无生成的日志文件。", "提示", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

$btnInstall.Add_Click({
    $selectedItems = @()
    foreach ($item in $listView.Items) {
        if ($item.Checked) {
            $selectedItems += $item
        }
    }

    if ($selectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("请至少勾选一款准备安装的软件！", "提示", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    # 关键安全机制：若勾选了「强制重新安装」，执行二次弹窗确认
    $isForceMode = $chkForceReinstall.Checked
    if ($isForceMode) {
        $confirmMsg = "【警告】您已启用「强制重新安装/覆盖」模式！`r`n`r`n这将对已存在的软件执行强行重新安装，可能会覆盖现有配置。`r`n`r`n是否确认继续批量执行？"
        $dialogRes = [System.Windows.Forms.MessageBox]::Show($confirmMsg, "二次安全确认", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($dialogRes -ne [System.Windows.Forms.DialogResult]::Yes) {
            Write-AppLog -Message "用户在二次确认中取消了强制重新安装流程。" -Level "INFO" -LogFile $currentLogFile -UiCallback $script:LogWriter
            return
        }
    }

    # 锁定控件
    $btnInstall.Enabled = $false
    $btnSelectAll.Enabled = $false
    $btnDeselectAll.Enabled = $false
    $btnRefresh.Enabled = $false
    $chkForceReinstall.Enabled = $false
    $listView.Enabled = $false

    $totalToInstall = $selectedItems.Count
    $successCount = 0
    $failCount = 0
    $skipCount = 0
    $progressBar.Value = 0

    Write-AppLog -Message "==================================================" -Level "INFO" -LogFile $currentLogFile -UiCallback $script:LogWriter
    Write-AppLog -Message "开始执行批量安装任务 | 待处理软件数: $totalToInstall | 强制模式: $isForceMode" -Level "INFO" -LogFile $currentLogFile -UiCallback $script:LogWriter

    for ($i = 0; $i -lt $totalToInstall; $i++) {
        $item = $selectedItems[$i]
        $data = $item.Tag
        $pkg = $data["Package"]
        $stepIndex = $i + 1

        $percent = [int](($i / $totalToInstall) * 100)
        $progressBar.Value = $percent
        $lblStats.Text = "正在安装 ($stepIndex/$totalToInstall): $($pkg['Name']) | 成功: $successCount | 失败: $failCount | 跳过: $skipCount"
        [System.Windows.Forms.Application]::DoEvents()

        # 调用核心安装器
        $result = Invoke-SoftwareInstall -Package $pkg -UsbRoot $UsbRoot -ForceReinstall $isForceMode -TimeoutSeconds 300 -LogFile $currentLogFile -UiCallback $script:LogWriter

        if ($result.Success) {
            $successCount++
            $item.SubItems[3].Text = "安装成功"
            $item.ForeColor = [System.Drawing.Color]::FromArgb(24, 134, 45)
        } elseif ($result.Skipped) {
            $skipCount++
            $item.SubItems[3].Text = "已跳过 ($($result.Message))"
            $item.ForeColor = [System.Drawing.Color]::FromArgb(101, 109, 118)
        } else {
            $failCount++
            $item.SubItems[3].Text = "安装失败 ($($result.Message))"
            $item.ForeColor = [System.Drawing.Color]::FromArgb(207, 34, 46)
        }

        [System.Windows.Forms.Application]::DoEvents()
    }

    $progressBar.Value = 100
    $lblStats.Text = "全部安装任务结束 | 总计: $totalToInstall | 成功: $successCount | 失败: $failCount | 跳过: $skipCount"
    Write-AppLog -Message "==================================================" -Level "INFO" -LogFile $currentLogFile -UiCallback $script:LogWriter
    Write-AppLog -Message "任务统计完成: 成功 $successCount 款, 失败 $failCount 款, 跳过 $skipCount 款" -Level "INFO" -LogFile $currentLogFile -UiCallback $script:LogWriter

    # 恢复控件
    $btnInstall.Enabled = $true
    $btnSelectAll.Enabled = $true
    $btnDeselectAll.Enabled = $true
    $btnRefresh.Enabled = $true
    $chkForceReinstall.Enabled = $true
    $listView.Enabled = $true

    $summaryMsg = "批量部署已完成！`r`n`r`n成功: $successCount 款`r`n失败: $failCount 款`r`n跳过: $skipCount 款`r`n`r`n详情可点击【查看完整日志】核对。"
    [System.Windows.Forms.MessageBox]::Show($summaryMsg, "安装结果", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$form.Add_Shown({
    try {
        Reload-PackageList
    } catch {
        $msg = "加载软件包列表时出现异常:`r`n" + $_.Exception.ToString()
        try {
            if ($currentLogFile) {
                Write-AppLog -Message $msg -Level "ERROR" -LogFile $currentLogFile
            }
        } catch {}
        [System.Windows.Forms.MessageBox]::Show($msg, "列表加载异常", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})

try {
    [void]$form.ShowDialog()
} catch {
    $errText = "装机助手运行中捕获到未处理异常:`r`n" + $_.Exception.ToString()
    try {
        if ($currentLogFile) {
            Write-AppLog -Message $errText -Level "FATAL" -LogFile $currentLogFile
        }
    } catch {}
    [System.Windows.Forms.MessageBox]::Show($errText, "装机助手错误", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    throw
}
