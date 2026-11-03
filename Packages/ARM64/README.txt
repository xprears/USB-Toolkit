=============================================================
  Packages\ARM64 离线安装包存放说明
=============================================================

本目录专门用于存放适用于 Windows 11 ARM64 架构（如 Mac 虚拟机、高通骁龙 PC）的原生离线安装包。

1. Google Chrome (ARM64 原生版)
- 支持格式：
  1) ChromeStandaloneSetup_ARM64.exe (官方独立离线包)
  或
  2) GoogleChromeStandaloneEnterprise_Arm64.msi (官方企业级 MSI 包)

- 官方下载途径：
  方法一：在 Chrome Enterprise 官方下载中心获取企业 MSI 包：
  https://chromeenterprise.google/download/
  -> Architecture 选择: 64 bit (ARM)
  -> File type 选择: MSI
  下载后重命名为 GoogleChromeStandaloneEnterprise_Arm64.msi 或 ChromeStandaloneSetup_ARM64.msi 放入本目录。

  方法二：通过官方独立离线链接：
  https://www.google.com/chrome/?standalone=1&platform=win_arm64

放入文件后，运行根目录下【Update-Hashes.bat】即可自动回填 SHA256 哈希值。
装机助手在 Windows 11 ARM64 环境下启动时，将自动精准识别并加载本目录软件。
