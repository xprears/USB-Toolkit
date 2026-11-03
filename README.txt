=============================================================
  Windows U 盘离线装机助手 (USB-Toolkit) 使用与部署说明
=============================================================

一、项目定位与特性
本工具专为 Windows 运维人员、装机工程师量身打造，支持在 Windows 7 SP1、
Windows 10 和 Windows 11 (x64 / ARM64) 系统上执行全离线、无外网依赖的常用软件批量部署。
支持物理 U 盘随身携带，亦支持一键打包为 ISO 光盘镜像挂载至虚拟机或服务器带外远程装机。

主要特点：
1. 纯绿色运行：无需固定盘符，全相对路径管理。
2. 零运行库依赖：严格原生兼容 Windows 7 SP1 自带的 PowerShell 2.0 与 .NET 3.5，
   无需提前在客户机安装 PowerShell 7、.NET 4.8 或第三方应用包管理器。
3. 智能环境感知：自动识别 Win7/Win10/Win11 及网络联通状态。
4. 严格版本隔离：Win7 环境只显示并运行通过验证的兼容版本（如 Chrome 109、专用版微信/WPS），
   彻底杜绝因误装 Win10 高版本而导致报错或系统崩溃。
5. 双重状态校验：安装完成后同时检测可执行文件或注册表真实存在性，不轻信安装包退出码。
6. 官方安装包下载器：提供 Download-Packages.bat，一键高速下载各官方离线包并校验 SHA256。
7. 原生 ISO 镜像打包：内置 Build-ISO.bat (Windows 原生 IMAPI2) 与 Build-ISO.sh (macOS/Linux)，
   支持只读介质日志自动重定向至 %TEMP%\USB-Toolkit\Logs，完美支持虚拟机装机。

二、目录结构规范
USB-Toolkit/
├── Start.bat                     <- 启动入口（自动请求管理员权限并纠正当前目录）
├── Download-Packages.bat         <- 官方离线安装包一键高速下载器（新用户/补包推荐）
├── Build-ISO.bat                 <- Windows 原生一键打包 ISO 光盘镜像（IMAPI2 零依赖）
├── Build-ISO.sh                  <- macOS / Linux 一键打包 ISO 光盘镜像
├── Update-Hashes.bat             <- 自动扫描安装包并更新 packages.ini 哈希值
├── autorun.inf                   <- 光盘/U 盘自动运行与盘符图标配置
├── Config/
│   ├── config.ini                <- 装机助手主配置（超时时间、标题等）
│   └── packages.ini              <- 软件包配置（软件名、路径、下载地址、参数、校验规则）
├── Packages/                     <- 离线安装包存放目录（可使用下载器一键补齐）
│   ├── Common/                   <- 全系统通用安装包（7-Zip、微信、纯净版WPS、输入法、播放器）
│   ├── Win7/                     <- Win7 专属兼容包（Chrome 109 等）
│   ├── Win10-11/                 <- Win10/Win11 最新离线安装包
│   └── ARM64/                    <- Windows 11 ARM64 原生离线安装包
├── Scripts/
│   ├── Utils.ps1                 <- 基础函数库（OS检测、哈希计算、INI解析、日志）
│   ├── Installer.ps1             <- 安装器核心（前置检查、静默调用、后置校验）
│   ├── GUI.ps1                   <- WinForms 图形交互主界面（含只读光盘自适应）
│   ├── Downloader.ps1            <- 官方软件包高速下载与哈希校验引擎
│   ├── Build-ISO.ps1             <- Windows 原生 ISO 生成核心脚本
│   ├── Updater.ps1               <- 哈希自动批量计算与回填脚本
│   └── Test-Toolkit.ps1          <- 自动化自检与模拟测试脚本
├── Logs/                         <- 安装日志输出目录（以时间戳命名）
├── README.md                     <- 项目 Markdown 格式说明文档
└── README.txt                    <- 本说明文档

三、官方离线安装包一键下载 (Download-Packages.bat)
为了保持 Git 仓库轻量，仓库不自带巨大体积的安装包二进制文件。
新用户在电脑联网时：
1. 双击根目录下【Download-Packages.bat】。
2. 程序支持一键全部下载、按核心软件下载、按编号单选下载，以及已有包 SHA256 体检。
3. 也可使用命令行批量下载：
   powershell.exe -ExecutionPolicy Bypass -File Scripts\Downloader.ps1 -All
   powershell.exe -ExecutionPolicy Bypass -File Scripts\Downloader.ps1 -Core
   powershell.exe -ExecutionPolicy Bypass -File Scripts\Downloader.ps1 -VerifyOnly

四、各软件包官方下载地址与放置对应表

1. 7-Zip 压缩软件 (64位)
   - 放置目录: Packages\Common\7z2408-x64.exe
   - 官方直链: https://www.7-zip.org/a/7z2408-x64.exe
   - 备用镜像: https://github.com/ip7z/7zip/releases/download/24.08/7z2408-x64.exe
   - 官方网站: https://www.7-zip.org/
   - 官方校验: 67cb9d3452c9dd974b04f4a5fd842dbcba8184f2344ff72e3662d7cdb68b099b
   - 静默参数: /S (必须大写)

2. Google Chrome 浏览器 (Win10/11 x64主流版)
   - 放置目录: Packages\Win10-11\ChromeStandaloneSetup64.exe
   - 官方直链: https://dl.google.com/tag/s/dl/chrome/install/ChromeStandaloneSetup64.exe
   - 官方网站: https://www.google.com/chrome/?standalone=1&platform=win64
   - 官方校验: d3d58b004932b2f4d1fbfd4b1638d56649779ea20a406489c83ff26ca8cbeb24
   - 静默参数: /silent /install /systemlevel

3. Google Chrome 浏览器 (Win11 ARM64原生版)
   - 放置目录: Packages\ARM64\GoogleChromeStandaloneEnterprise_Arm64.msi
   - 官方直链: https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise_Arm64.msi
   - 官方网站: https://chromeenterprise.google/download/
   - 官方校验: 8e5de3313c2d95ab9ed3592400fe655490f34f7cd015992d280342600b44ad8b
   - 静默参数: /qn /norestart

4. Google Chrome 浏览器 (Win7专属版 v109.0.5414.120)
   - 放置目录: Packages\Win7\ChromeStandaloneSetup64_109.exe
   - 官方归档: https://archive.org/download/google-chrome-109.0.5414.120_202601/109.0.5414.120_ChromeStandaloneSetup64.exe
   - 归档页面: https://archive.org/details/google-chrome-109.0.5414.120_202601
   - 官方校验: adc1a5953f2a7cb0ea42e02cf0a55787494b852ae575b24eca4cdb48d93853d1
   - 静默参数: /silent /install /systemlevel

5. 微信 (官网统一安装包)
   - 放置目录: Packages\Common\WeChatSetup.exe
   - 官方直链: https://dldir1.qq.com/weixin/Windows/WeChatSetup.exe
   - 官方网站: https://windows.weixin.qq.com/
   - 官方校验: c29fc05630cfc95ef6483f6b5b52aabfe74265bb260e210e78ae437d305d8990
   - 静默参数: /S (必须大写)

6. WPS Office 2019 专业纯净版 (考试教育版 - 默认推荐)
   - 放置目录: Packages\Common\WPS_Office_2019_Edu.exe
   - 官方来源: 中国教育考试网（NCRE）一级、二级 WPS 考试应用软件
   - 官方页面: https://ncre.neea.edu.cn/html1/report/1507/861-1.htm
   - 官方校验: c244d080721f04d858fe5b4a43961727ff76912b448bcc49a99ee9a8ff4d1482
   - 静默参数: /s
   - 特点: 零弹窗无广告，教育部考试中心合作版本，极度轻量纯净，通用兼容 Win7/Win10/Win11。

7. WPS Office 个人版 (最新64位可选包)
   - 放置目录: Packages\Win10-11\WPS_Setup_x64_29158.exe
   - 官方网站: https://www.wps.cn/
   - 官方校验: 1dd9f29797fa6d0a17a7f9ccc7ffef052f8a89327669570b77455a56fb9c4e3f
   - 静默参数: /s

8. 手心输入法 (无广告纯净版)
   - 放置目录: Packages\Common\PalmInputSetup.exe
   - 官方直链: https://dl.360safe.com/installer/web/PalmInputSetup.exe
   - 官方网站: http://www.shouxin168.com/
   - 官方校验: 7ac5dc3003b3df169e9ccbc557488c29f4559c517a5a14ee7798da75e0d82d7a
   - 静默参数: /s

9. PotPlayer 影音播放器 (64位)
   - 放置目录: Packages\Common\PotPlayerSetup64.exe
   - 官方直链: https://t1.daumcdn.net/potplayer/PotPlayer/Version/Latest/PotPlayerSetup64.exe
   - 官方网站: https://potplayer.tv/
   - 官方校验: 71374ce7f60136b8e8dd1618f736d37ccbefcc5875feb33650f9f8de0bba87e8
   - 静默参数: /S (必须大写)

10. VLC 媒体播放器 (64位)
    - 放置目录: Packages\Common\vlc-3.0.21-win64.exe
    - 官方直链: https://get.videolan.org/vlc/3.0.21/win64/vlc-3.0.21-win64.exe
    - 官方网站: https://www.videolan.org/vlc/download-windows.html
    - 官方校验: 9742689a50e96ddc04d80ceff046b28da2beefd617be18166f8c5e715ec60c59
    - 静默参数: /S (必须大写)

11. 搜狗拼音输入法 (经典版 7.9c)
    - 放置目录: Packages\Common\sogou_pinyin_79c.exe
    - 官方渠道: https://ime.sogou.com/
    - 官方校验: c13f1dab41ed445e2a0ebec741b3c997bc7a0aaa0540c928c1cd6eef672b7891
    - 静默参数: /S (必须大写)

五、ISO 光盘镜像制作与虚拟化部署 (Build-ISO.bat / Build-ISO.sh)
除了物理 U 盘使用外，本工具支持一键打包为标准 ISO9660/Joliet 镜像，方便在虚拟机
（VMware / VirtualBox / Hyper-V / Proxmox VE）或服务器带外远程控制台（iDRAC/iLO/IPMI）中挂载使用。

1. Windows 环境一键打包:
   - 双击根目录下【Build-ISO.bat】。
   - 采用 Windows 原生 IMAPI2 与 PowerShell，无需安装任何第三方工具，直接输出 USB-Toolkit.iso。

2. macOS / Linux 环境一键打包:
   - 执行 chmod +x Build-ISO.sh && ./Build-ISO.sh 即可。

3. 只读光盘专项适配:
   - 挂载 ISO 运行时，装机助手会自动识别只读状态，并将日志重定向至 %TEMP%\USB-Toolkit\Logs，杜绝报错。

六、运维工具与哈希维护
- 每次新增、替换或官方更新安装包后，双击运行根目录下【Update-Hashes.bat】，
  脚本将自动递归重新计算 Packages 目录下所有安装包的 SHA256 并精准写回 Config\packages.ini。

七、装机使用说明
1. 将本 USB-Toolkit 文件夹完整拷贝至 U 盘根目录，或使用 Build-ISO 打包为 ISO 镜像挂载。
2. 运行 Download-Packages.bat 下载安装包（或手动拷贝至 Packages 对应子目录）。
3. 在目标客户机上插入 U 盘或挂载 ISO，双击运行 Start.bat。
4. 系统弹出 UAC 提权请求时点击“是”，程序将自动唤起图形界面。
5. 界面会自动过滤当前系统支持的软件列表，并自动标出已安装或缺失状态。
6. 确认勾选项后，点击【开始一键安装】，界面将实时展示进度与详细日志。
7. 安装结束后可点击【查看完整日志】核验安装结果。

八、技术与兼容性说明
- 遵循原厂纯净部署原则，安装包一律采用官方完整离线包，禁止使用迷你在线下载器。
- Windows 7 必须为 SP1 补丁版本（Build 7601 及以上）。
- 若软件在某些定制精简系统上缺失运行库（如 VC++ 运行库），需先补齐系统基础组件。
