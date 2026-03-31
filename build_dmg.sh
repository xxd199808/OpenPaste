#!/bin/bash

# OpenPaste 打包脚本
# 用法: ./build_dmg.sh

set -e

echo "🔨 开始构建 OpenPaste..."

# 进入项目目录
cd "$(dirname "$0")"

# 清理旧的构建产物
rm -f OpenPaste.dmg
rm -rf dmg_temp

# 使用 xcodebuild 构建 Release 版本
echo "📦 构建 Release 版本..."
xcodebuild -scheme OpenPaste -configuration Release \
    BUILD_DIR=/tmp/xcode_build \
    DSTROOT=/tmp/xcode_sym \
    ONLY_ACTIVE_ARCH=YES

# 创建临时目录
mkdir -p dmg_temp

# 按顺序创建文件（影响 DMG 中的显示顺序）
echo "📋 准备 DMG 内容..."

# 1. 复制应用
cp -R /tmp/xcode_build/Release/OpenPaste.app dmg_temp/

# 2. 创建拖拽提示文件
cat > dmg_temp/"Drag OpenPaste → Applications to install.txt" << 'EOF'
Drag OpenPaste.app to Applications folder to install

First time: Right-click -> Open -> Open

If you see a security warning:

1. Open "System Settings" -> "Privacy & Security"
2. Find "OpenPaste" in the blocked list
3. Click "Open Anyway"
EOF

# 3. 创建 Applications 快捷方式
ln -s /Applications dmg_temp/Applications

# 创建 DMG
echo "💿 创建 DMG..."
hdiutil create OpenPaste.dmg \
    -volname "OpenPaste" \
    -srcfolder dmg_temp \
    -format UDZO \
    -imagekey zlib-level=9

# 清理临时文件
rm -rf dmg_temp

echo "✅ 打包完成！"
echo "📦 文件: OpenPaste.dmg"
ls -lh OpenPaste.dmg

# 可选：自动打开 DMG
# open OpenPaste.dmg
