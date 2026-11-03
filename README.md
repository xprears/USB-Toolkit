# Windows U 盘离线装机助手 (USB-Toolkit)

专为 Windows 运维人员、装机工程师量身打造的全离线、无外网依赖常用软件批量部署工具。支持在 **Windows 7 SP1**、**Windows 10**、**Windows 11 (x64 / ARM64)** 系统上一键静默装机。同时支持物理 U 盘随身携带与 **一键打包为 ISO 光盘镜像** 用于虚拟机及服务器带外远程挂载。

---

## ✨ 项目特性

1. **纯绿色 U 盘运行**：无需固定盘符，全相对路径自适应管理，即插即用。
2. **零运行库依赖**：严格原生兼容 Windows 7 SP1 自带的 **PowerShell 2.0 与 .NET 3.5**，无需预装 PowerShell 7、.NET 4.8 或第三方包管理器。
3. **智能环境感知**：自动识别操作系统版本（Win7 / Win10 / Win11）、硬件架构（x64 / ARM64 / x86）以及网络连通状态。
4. **严格版本隔离**：Win7 环境仅展示验证通过的兼容版本（如 Chrome 109、专用版微信/WPS），彻底杜绝误装 Win10 高版本导致的报错或系统崩溃。
5. **双重状态校验**：安装完成后同时检测文件物理路径或注册表真实存在性，不盲信安装包退出码。
6. **SHA256 哈希校验**：支持软件包完整性校验，内置运维工具一键自动更新哈希，防篡改防损坏。
7. **一键官方下载**：内置全自动官方安装包下载器，新用户拉取仓库后双击即可自动下载所有官方离线包并完成哈希对齐。
8. **ISO 镜像原生打包**：提供跨平台（Windows / macOS / Linux）一键 ISO 打包工具，支持虚拟机与只读介质自适应日志重定向。

---

## 📁 目录结构规范

```text
USB-Toolkit/
├── Start.bat                     <- 启动入口（自动请求管理员权限并纠正工作目录）
├── Download-Packages.bat         <- 官方离线安装包一键高速下载器（初次使用/补充安装包）
├── Build-ISO.bat                 <- Windows 原生一键打包 ISO 光盘镜像（IMAPI2 零依赖）
├── Build-ISO.sh                  <- macOS / Linux 环境一键打包 ISO 光盘镜像
├── Update-Hashes.bat             <- 自动扫描安装包并更新 packages.ini 哈希值
├── autorun.inf                   <- 光盘/U 盘自动运行与盘符图标配置
├── Config/
│   ├── config.ini                <- 装机助手主配置（超时时间、窗口标题等）
│   └── packages.ini              <- 软件包配置（软件名、路径、下载地址、静默参数、校验规则）
├── Packages/                     <- 离线安装包存放目录（可使用下载器一键补全）
│   ├── Common/                   <- 全系统通用安装包（7-Zip、微信、纯净版WPS、输入法、PotPlayer、VLC）
│   ├── Win7/                     <- Win7 专属兼容包（Chrome 109 等）
│   ├── Win10-11/                 <- Win10/Win11 最新离线安装包（Chrome最新版、WPS 64位等）
│   └── ARM64/                    <- Windows 11 ARM64 原生离线安装包（Chrome ARM64 等）
├── Scripts/
│   ├── Utils.ps1                 <- 基础函数库（OS检测、哈希计算、INI解析、日志）
│   ├── Installer.ps1             <- 安装器核心引擎（前置检查、静默调用、后置校验）
│   ├── GUI.ps1                   <- WinForms 图形交互主界面（含只读光盘介质自适应）
│   ├── Downloader.ps1            <- 官方软件包高速下载与哈希自动核验引擎
│   ├── Build-ISO.ps1             <- Windows 原生 ISO 生成核心脚本
│   ├── Updater.ps1               <- 哈希自动批量计算与回填脚本
│   └── Test-Toolkit.ps1          <- 自动化自检与模拟测试脚本
├── Logs/                         <- 安装日志输出目录（以时间戳自动命名）
├── README.md                     <- 项目说明文档
└── README.txt                    <- 控制台/离线纯文本说明
```

---

## 📥 官方离线安装包一键下载与快速准备

> **背景说明**：为了保持 GitHub 仓库体积轻量、便于克隆与分发，Git 仓库默认不打包体积庞大的可执行安装包（`*.exe` / `*.msi`）。
> 在首次克隆或下载本仓库后，您可以通过以下方式快速获取官方正版安装包：

### 🚀 方式一：Windows 一键全自动下载（强烈推荐）

在具有外网连接的电脑上：
1. 双击运行根目录下的 **`Download-Packages.bat`**。
2. 程序将自动检测网络、开启 TLS 1.2 高速传输通道，并展示功能菜单：
   - **`[1] 一键下载全部官方离线安装包`**：自动下载所有支持直链的官方原版安装包；
   - **`[2] 仅下载核心必备软件`**：仅下载 7-Zip、Chrome x64/ARM64、微信、PotPlayer、手心输入法、VLC；
   - **`[3] 自定义选择下载具体某一款软件`**：按需单选下载；
   - **`[4] 核验现有 Packages 离线安装包完整性`**：对已有安装包执行 SHA256 离线体检；
   - **`[5] 查看/打开需手动获取的官方门户`**：针对无静态直链的软件（如 WPS 教育考试纯净版），提供官方直达页面并支持一键在浏览器打开。
3. 下载过程支持**实时进度条、传输速率显示、断点与异常重试**。下载完成后会自动计算 SHA256 并与 `packages.ini` 严格校验，防止被篡改或损坏。

> 💡 **运维命令行静默下载示例**：
> ```cmd
> :: 下载全部直链官方安装包
> powershell.exe -ExecutionPolicy Bypass -File Scripts\Downloader.ps1 -All
> 
> :: 仅下载核心必备软件包
> powershell.exe -ExecutionPolicy Bypass -File Scripts\Downloader.ps1 -Core
> 
> :: 仅做本地 SHA256 完整性体检（不下载）
> powershell.exe -ExecutionPolicy Bypass -File Scripts\Downloader.ps1 -VerifyOnly
> ```

---

## 📦 软件包官方下载地址与放置配置总表

若您处于内网离线机房，可在能上网的机器上通过官方链接手动下载，并参照下表放置到对应目录：

| 软件名称 | 分类 | 放置相对路径与文件名 | 适用系统 | 官方下载直链 / 获取页面 | 官方校验 SHA256 | 默认安装 | 说明 |
| :--- | :--- | :--- | :--- | :--- | :--- | :---: | :--- |
| **7-Zip (64位)** | 实用工具 | `Packages\Common\7z2408-x64.exe` | Win7 / Win10 / Win11 | [官方直链](https://www.7-zip.org/a/7z2408-x64.exe)<br>[GitHub镜像](https://github.com/ip7z/7zip/releases/download/24.08/7z2408-x64.exe) | `67cb9d3452c9dd974b04f4a5fd842dbcba8184f2344ff72e3662d7cdb68b099b` | 是 | 官方开源压缩工具 (v24.08) |
| **Google Chrome (Win10/11 x64)** | 网络浏览 | `Packages\Win10-11\ChromeStandaloneSetup64.exe` | Win10 / Win11 (x64) | [官方直链](https://dl.google.com/tag/s/dl/chrome/install/ChromeStandaloneSetup64.exe)<br>[官网页面](https://www.google.com/chrome/?standalone=1&platform=win64) | `d3d58b004932b2f4d1fbfd4b1638d56649779ea20a406489c83ff26ca8cbeb24` | 是 | Google 官方 64 位独立离线包 |
| **Google Chrome (Win11 ARM64)** | 网络浏览 | `Packages\ARM64\GoogleChromeStandaloneEnterprise_Arm64.msi` | Win11 (ARM64) | [官方直链](https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise_Arm64.msi)<br>[官网页面](https://chromeenterprise.google/download/) | `8e5de3313c2d95ab9ed3592400fe655490f34f7cd015992d280342600b44ad8b` | 是 | Chrome Enterprise 官方 ARM64 原生 MSI 包 |
| **Google Chrome (Win7 专属版)** | 网络浏览 | `Packages\Win7\ChromeStandaloneSetup64_109.exe` | Win7 (x64) | [官方归档直链](https://archive.org/download/google-chrome-109.0.5414.120_202601/109.0.5414.120_ChromeStandaloneSetup64.exe)<br>[归档页面](https://archive.org/details/google-chrome-109.0.5414.120_202601) | `adc1a5953f2a7cb0ea42e02cf0a55787494b852ae575b24eca4cdb48d93853d1` | 是 | Win7 最终官方支持版本 (v109.0.5414.120) |
| **微信 (WeChat)** | 社交沟通 | `Packages\Common\WeChatSetup.exe` | Win7 / Win10 / Win11 | [官方直链](https://dldir1.qq.com/weixin/Windows/WeChatSetup.exe)<br>[官网页面](https://windows.weixin.qq.com/) | `c29fc05630cfc95ef6483f6b5b52aabfe74265bb260e210e78ae437d305d8990` | 是 | 腾讯官方统一离线安装包 (v3.9.12.57) |
| **WPS Office 2019 (教育纯净版)** | 办公软件 | `Packages\Common\WPS_Office_2019_Edu.exe` | Win7 / Win10 / Win11 | [中国教育考试网](https://ncre.neea.edu.cn/html1/report/1507/861-1.htm) | `c244d080721f04d858fe5b4a43961727ff76912b448bcc49a99ee9a8ff4d1482` | 是 | 教育部考试中心合作版，零弹窗无广告（默认主选） |
| **WPS Office 个人版 (64位可选)** | 办公软件 | `Packages\Win10-11\WPS_Setup_x64_29158.exe` | Win10 / Win11 | [金山 WPS 官网](https://www.wps.cn/) | `1dd9f29797fa6d0a17a7f9ccc7ffef052f8a89327669570b77455a56fb9c4e3f` | 否 | 官方最新 64 位完整离线包（备选高版本） |
| **手心输入法 (无广告纯净版)** | 输入法 | `Packages\Common\PalmInputSetup.exe` | Win7 / Win10 / Win11 | [官方直链](https://dl.360safe.com/installer/web/PalmInputSetup.exe)<br>[官网页面](http://www.shouxin168.com/) | `7ac5dc3003b3df169e9ccbc557488c29f4559c517a5a14ee7798da75e0d82d7a` | 是 | 纯净无广告输入法 (v3.3.0.1030) |
| **PotPlayer 影音播放器 (64位)** | 影音媒体 | `Packages\Common\PotPlayerSetup64.exe` | Win7 / Win10 / Win11 | [官方直链](https://t1.daumcdn.net/potplayer/PotPlayer/Version/Latest/PotPlayerSetup64.exe)<br>[官网页面](https://potplayer.tv/) | `71374ce7f60136b8e8dd1618f736d37ccbefcc5875feb33650f9f8de0bba87e8` | 是 | Kakao 官方全能影音播放器 |
| **VLC 媒体播放器 (64位)** | 影音媒体 | `Packages\Common\vlc-3.0.21-win64.exe` | Win7 / Win10 / Win11 | [官方直链](https://get.videolan.org/vlc/3.0.21/win64/vlc-3.0.21-win64.exe)<br>[官网页面](https://www.videolan.org/vlc/download-windows.html) | `9742689a50e96ddc04d80ceff046b28da2beefd617be18166f8c5e715ec60c59` | 是 | VideoLAN 官方开源播放器 (v3.0.21) |
| **搜狗拼音输入法 (经典版 7.9c)** | 输入法 | `Packages\Common\sogou_pinyin_79c.exe` | Win7 / Win10 / Win11 | [搜狗官网](https://ime.sogou.com/) | `c13f1dab41ed445e2a0ebec741b3c997bc7a0aaa0540c928c1cd6eef672b7891` | 否 | 官方经典无广告弹窗版 (7.9.0.7504，备选) |

---

## 💿 ISO 光盘镜像打包与虚拟化支持

除了直接放入物理 U 盘随身携带之外，本项目针对 **虚拟机批量装机（VMware Workstation / ESXi、Proxmox VE、VirtualBox、Hyper-V、Parallels Desktop）** 以及 **服务器远程带外管理（Dell iDRAC、HP iLO、联想 XCC、通用 IPMI 虚拟光盘挂载）** 进行了专项优化：

### ✨ 光盘环境专项适配
1. **只读介质无感降级**：当工具在只读光盘（CD/DVD ISO）或写保护 U 盘中启动时，[`Scripts/GUI.ps1`](Scripts/GUI.ps1) 会自动捕获介质只读属性，并自动将装机日志平滑重定向至本地临时目录（`%TEMP%\USB-Toolkit\Logs`），杜绝因光盘无法写入而导致的报错或退出。
2. **自动运行与专属盘符图标**：内置 [`autorun.inf`](autorun.inf)，挂载 ISO 或插入 U 盘后在“此电脑”中自动呈现装机助手专属图标与一键运行菜单。

### 🔨 一键生成 ISO 镜像

当您通过 `Download-Packages.bat` 或手动下载将离线安装包放入 `Packages` 目录后，可随时将其打包为标准 ISO9660/Joliet 镜像：

#### 方案一：Windows 环境原生一键打包（推荐，零外部依赖）
- 双击运行根目录下的 **`Build-ISO.bat`**。
- 脚本直接调用 Windows 系统内置的 **IMAPI2 (Microsoft File System Image)** 接口与 PowerShell，**无需安装 UltraISO、软碟通、oscdimg 或任何第三方软件**。
- 自动排除 `.git`、临时日志与非必要缓存文件，并在根目录下输出标准光盘镜像 `USB-Toolkit.iso`。

#### 方案二：macOS / Linux 环境一键打包
- 在终端进入 `USB-Toolkit` 根目录，执行：
  ```bash
  chmod +x Build-ISO.sh
  ./Build-ISO.sh [可选输出路径，默认输出当前目录 USB-Toolkit.iso]
  ```
- 脚本利用 macOS 原生 `hdiutil makehybrid` 工具，一键生成全系统兼容的混合 ISO 镜像。

---

## 🛠️ 运维工具与哈希自动维护

### 1. 软件官方推送更新后的哈希更新
当软件官方（如 Chrome、微信）推送新版，导致直链下载的文件哈希发生变化时：
- 在 Windows 环境下双击运行根目录的 **`Update-Hashes.bat`**。
- 脚本会自动递归计算所有已放入 `Packages` 目录的安装包真实 SHA256，并精准回填更新 `Config\packages.ini`。

---

## 🚀 装机使用方法

1. 将 `USB-Toolkit` 文件夹拷贝至 U 盘根目录，或使用 `Build-ISO.bat` 打包为 ISO 镜像挂载至虚拟机/服务器。
2. 运行 **`Download-Packages.bat`** 下载安装包（或手动将安装包放入 `Packages` 对应子目录）。
3. 在需要装机的目标客户机上插入 U 盘或挂载 ISO，双击运行 **`Start.bat`**。
4. 弹出 UAC 提权提示时点击“是”，程序将自动拉起 WinForms 图形化交互界面。
5. 界面会自动过滤出当前操作系统兼容的软件列表，并自动检测当前系统是否已安装。
6. 勾选需要安装的软件，点击 **【开始一键安装】**，即可全自动静默批量部署。
7. 安装完成后可点击 **【查看完整日志】** 校验安装细节（本地正常介质保存在 `Logs/` 目录，只读 ISO 介质保存在 `%TEMP%\USB-Toolkit\Logs`）。

---

## ⚠️ 兼容性与技术注意事项

- **离线原则**：本工具严禁使用任何“微型在线下载器”，所有包体必须为官方完整的离线安装包。
- **Windows 7 兼容要求**：必须为 **Windows 7 SP1 (Build 7601)** 及以上版本。
- **精简系统依赖**：若某些极限精简系统缺失系统基础库（如 VC++ 运行库），需先补齐相应组件。
