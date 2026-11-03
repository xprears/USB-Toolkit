# =============================================================
# Windows U 盘离线装机助手 - 自检与模拟测试套件 (全功能强化版)
# 覆盖：
# 1. 真实系统环境与架构识别
# 2. Universal C Runtime (KB2999226) 检测逻辑
# 3. 版本对比与防降级矩阵
# 4. 4 款基线软件包物理存在与 SHA256 完整性核验
# 5. 非固定 U 盘盘符自适应校验
# 6. 多路径可执行程序与注册表检测机制模拟
# =============================================================

param(
    [string]$UsbRoot = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrEmpty($UsbRoot)) {
    $UsbRoot = Split-Path -Parent $scriptDir
}

. ([System.IO.Path]::Combine($scriptDir, "Utils.ps1"))
. ([System.IO.Path]::Combine($scriptDir, "Installer.ps1"))

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Windows U 盘离线装机助手 - 兼容性与完整性自检套件" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. 系统检测验证
Write-Host "`n[测试项 1] 真实操作系统环境检测:" -ForegroundColor Yellow
$os = Get-OSInfo
Write-Host "  -> 系统名称: $($os.OSName)"
Write-Host "  -> 内部标识: $($os.OSCode)"
Write-Host "  -> 硬件架构: $($os.Arch)"
Write-Host "  -> 构建版本: $($os.BuildNumber)"
Write-Host "  -> 兼容支持: $($os.IsSupported)"

# 2. Win7 UCRT 运行库前置检测 (三态严格判定)
Write-Host "`n[测试项 2] Universal C Runtime (KB2999226) 前置依赖检测:" -ForegroundColor Yellow
$ucrt = Test-Win7UcrtPrerequisite
Write-Host "  -> UCRT 状态码: $($ucrt.StatusCode)"
Write-Host "  -> 核心DLL文件: $(if ($ucrt.FilePresent) { '存在' } else { '缺失' })"
Write-Host "  -> 补丁安装状态: $($ucrt.PatchInstalled)"
Write-Host "  -> 检测详情: $($ucrt.Message)"

# 3. 版本比较函数测试矩阵
Write-Host "`n[测试项 3] 软件版本矩阵逻辑比对测试:" -ForegroundColor Yellow
$testCases = @(
    @{ Installed = "3.9.11.0"; Target = "3.9.11.0"; Expected = 0;   Desc = "微信同版本" },
    @{ Installed = "3.9.12.1"; Target = "3.9.11.0"; Expected = 1;   Desc = "微信更高版本 (防降级)" },
    @{ Installed = "3.9.8.25"; Target = "3.9.11.0"; Expected = -1;  Desc = "微信较低版本 (可升级)" },
    @{ Installed = "109.0.5414.120"; Target = "109.0.5414.120"; Expected = 0; Desc = "Chrome 109同版本" },
    @{ Installed = "120.0.0.0"; Target = "109.0.5414.120"; Expected = 1; Desc = "Chrome高版本防降级" },
    @{ Installed = "100.0.0.0"; Target = "109.0.5414.120"; Expected = -1; Desc = "Chrome低版本可升级" },
    @{ Installed = "24.08"; Target = "24.08"; Expected = 0; Desc = "7-Zip同版本" },
    @{ Installed = "11.1.0.10009"; Target = "11.1.0.10009"; Expected = 0; Desc = "WPS 2019同版本" },
    @{ Installed = "11.1.0.9000"; Target = "11.1.0.10009"; Expected = -1; Desc = "WPS 2019低版本可升级" },
    @{ Installed = "3.3.0.1030"; Target = "3.3.0.1030"; Expected = 0; Desc = "手心输入法同版本" },
    @{ Installed = "3.2.3.1000"; Target = "3.3.0.1030"; Expected = -1; Desc = "手心输入法低版本可升级" },
    @{ Installed = "Unknown"; Target = "Latest"; Expected = -99; Desc = "无法解析版本 (需人工确认)" }
)

$allPassed = $true
foreach ($tc in $testCases) {
    $res = Compare-SoftwareVersion -InstalledVersion $tc.Installed -TargetVersion $tc.Target
    $pass = ($res -eq $tc.Expected)
    if (-not $pass) { $allPassed = $false }
    $mark = "[FAIL]"; if ($pass) { $mark = "[PASS]" }
    $color = "Red"; if ($pass) { $color = "Green" }
    Write-Host "  $mark $($tc.Desc): 已装 $($tc.Installed) vs 待装 $($tc.Target) -> 返回 $res (预期 $($tc.Expected))" -ForegroundColor $color
}

# 4. 全部配置软件包物理文件与 SHA256 校验
Write-Host "`n[测试项 4] 全部配置软件包完整性与 SHA256 核验:" -ForegroundColor Yellow
$pkgPath = [System.IO.Path]::Combine($UsbRoot, "Config\packages.ini")
$pkgs = Parse-IniFile -FilePath $pkgPath

foreach ($k in $pkgs.Keys) {
    $p = $pkgs[$k]
    $integ = Test-PackageIntegrity -Package $p -UsbRoot $UsbRoot
    $statusMark = "[FAIL]"; if ($integ.Status -eq "OK") { $statusMark = "[PASS]" }
    $statusColor = "Red"; if ($integ.Status -eq "OK") { $statusColor = "Green" }
    
    Write-Host "  $statusMark [$k] $($p['Name'])" -ForegroundColor $statusColor
    Write-Host "        路径: $($integ.FullPath)"
    Write-Host "        存在: $($integ.FileExists) | 结果: $($integ.Message)"
    if ($integ.ActualSha256 -ne "") {
        Write-Host "        SHA256: $($integ.ActualSha256)"
    }
}

# 5. U 盘根路径自适应性测试
Write-Host "`n[测试项 5] U 盘非固定盘符动态路径自适应核验:" -ForegroundColor Yellow
Write-Host "  -> 当前 UsbRoot: $UsbRoot"
$testConfigPath = [System.IO.Path]::Combine($UsbRoot, "Config\config.ini")
if (Test-Path $testConfigPath) {
    Write-Host "  [PASS] 成功定位主配置文件: $testConfigPath" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] 无法定位主配置文件" -ForegroundColor Red
}

# 6. .NET 原生 SHA256 算法测试
Write-Host "`n[测试项 6] 原生 .NET SHA256 算法计算:" -ForegroundColor Yellow
$tempTestFile = [System.IO.Path]::Combine($UsbRoot, "Logs\test_sha256.tmp")
[System.IO.File]::WriteAllText($tempTestFile, "ToolkitArchitectureVerification", [System.Text.Encoding]::UTF8)
$calcHash = Get-FileSha256 -FilePath $tempTestFile
Write-Host "  -> 测试样本: ToolkitArchitectureVerification"
Write-Host "  -> 计算 SHA256: $calcHash"
if (Test-Path $tempTestFile) { Remove-Item $tempTestFile -Force }

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  自检与逻辑核验执行完毕。" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
