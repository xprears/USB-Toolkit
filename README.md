# Windows U 盘离线装机助手 (USB-Toolkit)

专为 Windows 运维人员、装机工程师量身打造的全离线、无外网依赖常用软件批量部署工具。支持在 **Windows 7 SP1**、**Windows 10**、**Windows 11 (x64 / ARM64)** 系统上一键静默装机。

---

## ✨ 项目特性

1. **纯绿色 U 盘运行**：无需固定盘符，全相对路径自适应管理，即插即用。
2. **零运行库依赖**：严格原生兼容 Windows 7 SP1 自带的 **PowerShell 2.0 与 .NET 3.5**，无需预装 PowerShell 7、.NET 4.8 或第三方包管理器。
3. **智能环境感知**：自动识别操作系统版本（Win7 / Win10 / Win11）、硬件架构（x64 / ARM64 / x86）以及网络连通状态。
4. **严格版本隔离**：Win7 环境仅展示验证通过的兼容版本（如 Chrome 109、专用版微信/WPS），彻底杜绝误装 Win10 高版本导致的报错或系统崩溃。
5. **双重状态校验**：安装完成后同时检测文件物理路径或注册表真实存在性，不盲信安装包退出码。
6. **SHA256 哈希校验**：支持软件包完整性校验，内置运维工具一键自动更新哈希，防篡改防损坏。

---

## 📁 目录结构规范

```text
USB-Toolkit/
├── Start.bat                     <- 启动入口（自动请求管理员权限并纠正工作目录）
├── Update-Hashes.bat             <- 自动扫描安装包并更新 packages.ini 哈希值
├── Config/
│   ├── config.ini                <- 装机助手主配置（超时时间、窗口标题等）
│   └── packages.ini              <- 软件包配置（软件名、路径、静默参数、校验规则）
├── Packages/                     <- 离线安装包存放目录（需运维人员自行放入）
│   ├── Common/                   <- 全系统通用安装包（如 7-Zip、微信、纯净版WPS、输入法、PotPlayer）
│   ├── Win7/                     <- Win7 专属兼容包（Chrome 109 等）
│   ├── Win10-11/                 <- Win10/Win11 最新离线安装包（Chrome最新版、WPS 64位等）
│   └── ARM64/                    <- Windows 11 ARM64 原生离线安装包（Chrome ARM64 等）
├── Scripts/
│   ├── Utils.ps1                 <- 基础函数库（OS检测、哈希计算、INI解析、日志）
│   ├── Installer.ps1             <- 安装器核心引擎（前置检查、静默调用、后置校验）
│   ├── GUI.ps1                   <- WinForms 图形交互主界面
│   ├── Updater.ps1               <- 哈希自动批量计算与回填脚本
│   └── Test-Toolkit.ps1          <- 自动化自检与模拟测试脚本
├── Logs/                         <- 安装日志输出目录（以时间戳自动命名）
├── README.md                     <- 项目说明文档
└── README.txt                    <- 控制台/离线纯文本说明
```

---

## 📦 软件包配置与放置指南

> **说明**：为了保持代码仓库精简，Git 仓库不包含体积庞大的安装包二进制文件（`*.exe` / `*.msi`）。请在使用前根据下表将官方离线安装包下载并放置到对应目录：

| 软件名称 | 放置目录与文件名 | 适用系统 | 静默参数 | 校验状态 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **7-Zip (64位)** | `Packages\Common\7z2408-x64.exe` | Win7 / Win10 / Win11 | `/S` | 已验证 | 官方开源压缩工具 |
| **Google Chrome (Win7专用)** | `Packages\Win7\ChromeStandaloneSetup64_109.exe` | Win7 (x64) | `/silent /install` | 已验证 | Win7 最终支持版本 (v109.0.5414.120) |
| **Google Chrome (Win10/11)** | `Packages\Win10-11\ChromeStandaloneSetup64.exe` | Win10 / Win11 (x64) | `/silent /install` | 已验证 | 官方 64 位独立离线包 |
| **Google Chrome (ARM64)** | `Packages\ARM64\GoogleChromeStandaloneEnterprise_Arm64.msi` | Win11 (ARM64) | `/qn /norestart` | 已验证 | Chrome Enterprise 官方 MSI 安装包 |
| **微信 (WeChat)** | `Packages\Common\WeChatSetup.exe` | Win7 / Win10 / Win11 | `/S` | 待验证 | 官方安装包 |
| **WPS Office 2019 (教育纯净版)** | `Packages\Common\WPS_Office_2019_Edu.exe` | Win7 / Win10 / Win11 | `/s` | 已验证 | 教育部考试中心合作版，零弹窗无广告（默认主选） |
| **WPS Office 个人版 (64位)** | `Packages\Win10-11\WPS_Setup_x64_29158.exe` | Win10 / Win11 | `/s` | 已验证 | 官方 64 位完整离线包（备选） |
| **手心输入法 (纯净版)** | `Packages\Common\PalmInputSetup.exe` | Win7 / Win10 / Win11 | `/s` | 静态检查通过 | 无广告纯净输入法 (v3.3.0.1030) |
| **搜狗拼音输入法 (经典版 7.9c)** | `Packages\Common\sogou_pinyin_79c.exe` | Win7 / Win10 / Win11 | `/S` | 静态检查通过 | 官方经典版 (7.9.0.7504)，核心签名有效（备选） |
| **PotPlayer 影音播放器 (64位)** | `Packages\Common\PotPlayerSetup64.exe` | Win7 / Win10 / Win11 | `/S` | 静态检查通过 | Kakao 官方全能影音播放器 |

---

## 🛠️ 运维工具与哈希维护

每次向 `Packages` 目录新增、替换安装包后：
- 在 Windows 环境下双击运行根目录的 **`Update-Hashes.bat`**。
- 脚本会自动递归计算所有安装包的真实 SHA256 哈希，并精准回填更新 `Config\packages.ini`，确保装机过程防损坏与防投毒。

---

## 🚀 使用方法

1. 将 `USB-Toolkit` 文件夹拷贝至 U 盘根目录。
2. 参照上述表格将各官方离线安装包放入 `Packages` 对应子目录中。
3. 在需要装机的目标客户机上插入 U 盘，双击运行 **`Start.bat`**。
4. 弹出 UAC 提权提示时点击“是”，程序将自动拉起 WinForms 图形化交互界面。
5. 界面会自动过滤出当前操作系统兼容的软件列表，并自动检测当前系统是否已安装。
6. 勾选需要安装的软件，点击 **【开始一键安装】**，即可全自动静默批量部署。
7. 安装完成后可点击 **【查看完整日志】** 校验安装细节（日志保存在 `Logs/` 目录）。

---

## ⚠️ 兼容性与技术注意事项

- **离线原则**：本工具严禁使用任何“微型在线下载器”，所有包体必须为官方完整的离线安装包。
- **Windows 7 兼容要求**：必须为 **Windows 7 SP1 (Build 7601)** 及以上版本。
- **精简系统依赖**：若某些极限精简的系统缺失系统基础库（如 VC++ 运行库），需先补齐相应组件。
