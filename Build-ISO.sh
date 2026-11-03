#!/usr/bin/env bash
# =============================================================
# 一键生成 Windows 离线装机助手 ISO 光盘镜像 (macOS 环境)
# =============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_ISO="${1:-$SCRIPT_DIR/USB-Toolkit.iso}"
STAGING_DIR="/tmp/USB-Toolkit-ISO-Staging"

echo "=================================================="
echo "正在打包 Windows 离线装机助手 ISO 镜像..."
echo "源码目录: $SCRIPT_DIR"
echo "输出目标: $OUTPUT_ISO"
echo "=================================================="

# 1. 清理并创建临时暂存目录
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# 2. 拷贝必要文件，彻底排除 Git 仓库、macOS 隐藏文件和历史日志
echo "[1/3] 正在准备光盘数据文件..."
rsync -a \
  --exclude='.git' \
  --exclude='.gitignore' \
  --exclude='.gitattributes' \
  --exclude='.DS_Store' \
  --exclude='._*' \
  --exclude='Logs/*.log' \
  --exclude='*.iso' \
  --exclude='Build-ISO.sh' \
  "$SCRIPT_DIR/" "$STAGING_DIR/"

# 3. 调用 macOS 原生工具生成 Joliet/ISO9660 混合镜像
echo "[2/3] 正在生成 ISO 混合镜像..."
hdiutil makehybrid -iso -joliet -default-volume-name "USB_TOOLKIT" -ov -o "$OUTPUT_ISO" "$STAGING_DIR"

# 4. 清理暂存目录
echo "[3/3] 清理临时暂存区..."
rm -rf "$STAGING_DIR"

echo "=================================================="
echo "✅ ISO 镜像打包成功！"
ls -lh "$OUTPUT_ISO"
echo "=================================================="
