=============================================================
  Windows U 盘离线装机助手 (USB-Toolkit) 使用与部署说明
=============================================================

一、项目定位与特性
本工具专为 Windows 运维人员、装机工程师量身打造，支持在 Windows 7 SP1、
Windows 10 和 Windows 11 (64位) 系统上执行全离线、无外网依赖的常用软件批量部署。

主要特点：
1. 纯绿色 U 盘运行：无需固定盘符，全相对路径管理。
2. 零运行库依赖：严格原生兼容 Windows 7 SP1 自带的 PowerShell 2.0 与 .NET 3.5，
   无需提前在客户机安装 PowerShell 7、.NET 4.8 或第三方应用包管理器。
3. 智能环境感知：自动识别 Win7/Win10/Win11 及网络联通状态。
4. 严格版本隔离：Win7 环境只显示并通过经过验证的兼容版本（如 Chrome 109、专用版微信/WPS），
   彻底杜绝因误装 Win10 新版而导致报错或系统崩溃。
5. 双重状态校验：安装完成后同时检测可执行文件或注册表真实存在性，不轻信安装包退出码。

二、目录结构规范
USB-Toolkit/
├── Start.bat                     <- 启动入口（自动请求管理员权限并纠正当前目录）
├── Config/
│   ├── config.ini                <- 装机助手主配置（超时时间、标题等）
│   └── packages.ini              <- 软件包配置（软件名、路径、参数、校验规则）
├── Packages/                     <- 离线安装包存放目录
│   ├── Common/                   <- 全系统通用安装包（如 7-Zip x64）
│   ├── Win7/                     <- Win7 专属兼容包（Chrome 109、Win7微信、Win7 WPS）
│   └── Win10-11/                 <- Win10/Win11 最新离线安装包
├── Scripts/
│   ├── Utils.ps1                 <- 基础函数库（OS检测、哈希计算、INI解析、日志）
│   ├── Installer.ps1             <- 安装器核心（前置检查、静默调用、后置校验）
│   ├── GUI.ps1                   <- WinForms 图形交互主界面
│   └── Test-Toolkit.ps1          <- 自动化自检与模拟测试脚本
├── Logs/                         <- 安装日志输出目录（以时间戳命名）
└── README.txt                    <- 本说明文档

三、首批软件配置与放置指南

1. 7-Zip 压缩软件 (64位)
   - 放置目录: Packages\Common\7z2408-x64.exe
   - 静默参数: /S (必须大写)
   - 适用系统: Win7 / Win10 / Win11 通用
   - 验证状态: 已验证 (Verified)

2. Google Chrome 浏览器
   - Win7 专用: Packages\Win7\ChromeStandaloneSetup64_109.exe (v109.0.5414.120)
   - Win10/11: Packages\Win10-11\ChromeStandaloneSetup64.exe (最新独立版)
   - 静默参数: /silent /install
   - 验证状态: 已验证 (Verified)

3. 微信
   - 放置目录: Packages\Common\WeChatSetup.exe
   - 官方来源: 微信官网统一安装包 (https://windows.weixin.qq.com)
   - 静默参数: /S (必须大写)
   - 验证状态: 待验证 (PendingVerification) - 待在 Win7 SP1 虚拟机实测离线安装与运行时稳定性

4. WPS Office 2019 专业纯净版 (考试教育版 - 默认主选)
   - 放置目录: Packages\Common\WPS_Office_2019_Edu.exe
   - 官方来源: 教育部考试中心/金山官方合作考试专用版 (149.13 MB)
   - 软件版本: v11.1.0.10009
   - SHA256: c244d080721f04d858fe5b4a43961727ff76912b448bcc49a99ee9a8ff4d1482
   - 静默参数: /s
   - 特点与适用: 零弹窗、无推广、极度轻量纯净；Win7 / Win10 / Win11 原生通用默认勾选
   - 验证状态: 已验证 (Verified)

5. WPS Office 个人版 (最新64位可选包)
   - 放置目录: Packages\Win10-11\WPS_Setup_x64_29158.exe
   - 官方来源: 官方 64 位完整离线安装包 (356.77 MB，珠海金山办公软件有限公司数字签名)
   - 软件版本: v12.1.0.29158
   - SHA256: 1dd9f29797fa6d0a17a7f9ccc7ffef052f8a89327669570b77455a56fb9c4e3f
   - 静默参数: /s
   - 适用系统: Win10 / Win11 (默认不勾选，备选高版本)
   - 验证状态: 已验证 (Verified)

6. 手心输入法 (无广告纯净版)
   - 放置目录: Packages\Common\PalmInputSetup.exe
   - 官方来源: 官方原版完整离线安装包 (https://www.xinshuru.com / 北京奇元科技有限公司数字签名)
   - 软件版本: v3.3.0.1030
   - SHA256: 7ac5dc3003b3df169e9ccbc557488c29f4559c517a5a14ee7798da75e0d82d7a
   - 静默参数: /s
   - 适用系统: Win7 / Win10 / Win11 通用 (x64 / ARM64仿真 / x86)
   - 验证状态: 静态检查通过 (StaticCheckPassed)

7. 搜狗拼音输入法 (经典版 7.9c)
   - 放置目录: Packages\Common\sogou_pinyin_79c.exe
   - 官方来源: 搜狗官方渠道离线安装包 (23.95 MB / 核心组件北京搜狗科技有效签名)
   - 软件版本: v7.9.0.7504
   - SHA256: c13f1dab41ed445e2a0ebec741b3c997bc7a0aaa0540c928c1cd6eef672b7891
   - 静默参数: /S (必须大写)
   - 适用系统: Win7 / Win10 / Win11 通用 (默认不勾选，备选输入法)
   - 验证状态: 静态检查通过 (StaticCheckPassed)

8. PotPlayer 影音播放器 (64位)
   - 放置目录: Packages\Common\PotPlayerSetup64.exe
   - 官方来源: Kakao/Daum 官网官方 CDN (https://potplayer.tv / Kakao Corp. 数字签名)
   - 软件版本: v26.10.21.0 (v1.7.23159)
   - SHA256: 71374ce7f60136b8e8dd1618f736d37ccbefcc5875feb33650f9f8de0bba87e8
   - 静默参数: /S (必须大写)
   - 适用系统: Win7 / Win10 / Win11 通用 (x64 / ARM64)
   - 验证状态: 静态检查通过 (StaticCheckPassed)

9. VLC 媒体播放器 (64位)
   - 放置目录: Packages\Common\vlc-3.0.21-win64.exe
   - 官方来源: VideoLAN 官方 / 清华开源镜像站 (https://get.videolan.org/vlc/3.0.21/win64/)
   - 软件版本: v3.0.21
   - SHA256: 9742689a50e96ddc04d80ceff046b28da2beefd617be18166f8c5e715ec60c59
   - 静默参数: /S (必须大写)
   - 适用系统: Win7 / Win10 / Win11 通用 (x64 / ARM64)
   - 验证状态: 静态检查通过 (StaticCheckPassed)




四、运维工具与哈希维护
- 双击运行根目录下【Update-Hashes.bat】，即可自动扫描 Packages 下的所有软件包，
  并在 Config\packages.ini 中自动计算并回填准确的 SHA256 哈希值，防止文件被篡改。

四、使用说明
1. 将本 USB-Toolkit 文件夹完整拷贝至 U 盘根目录。
2. 将对应的官方离线安装包放入上述 Packages 对应子目录中。
3. 在目标客户机上插入 U 盘，双击运行 Start.bat。
4. 系统弹出 UAC 提权请求时点击“是”，程序将自动唤起图形界面。
5. 界面会自动过滤当前系统支持的软件列表，并自动标出已安装或文件缺失状态。
6. 确认勾选项后，点击【开始一键安装】，界面将实时展示进度与详细日志。
7. 安装结束后可点击【查看完整日志】核验安装结果。

五、技术与兼容性说明
- 遵循原厂纯净部署原则，安装包一律采用官方完整离线包，禁止使用迷你在线下载器。
- Windows 7 必须为 SP1 补丁版本（Build 7601 及以上）。
- 若软件在某些定制精简系统上缺失运行库（如 VC++ 运行库），需先补齐系统基础组件。
