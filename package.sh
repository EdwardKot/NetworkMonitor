#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="NetworkMonitor"
BUILD_DIR="${PROJECT_DIR}/.build/release"
APP_DIR="${PROJECT_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"

echo "🚀 开始打包 ${APP_NAME}..."

# 1. 清理旧构建
echo "🧹 清理旧构建..."
rm -rf "${BUILD_DIR}"
rm -rf "${APP_DIR}"
rm -f "${PROJECT_DIR}/${DMG_NAME}"

# 2. 构建 release 版本
echo "🔨 构建 release 版本..."
cd "${PROJECT_DIR}"
swift build -c release

# 3. 创建 .app 目录结构
echo "📦 创建 .app 结构..."
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# 4. 复制可执行文件
echo "📋 复制可执行文件..."
cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# 5. 创建 Info.plist
echo "📝 创建 Info.plist..."
cat > "${APP_DIR}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>NetworkMonitor</string>
    <key>CFBundleIconFile</key>
    <string></string>
    <key>CFBundleIdentifier</key>
    <string>com.networkmonitor.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NetworkMonitor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
EOF

# 6. 复制 Resources（如果有）
if [ -d "${PROJECT_DIR}/Resources" ]; then
    cp -r "${PROJECT_DIR}/Resources/." "${APP_DIR}/Contents/Resources/"
fi

# 7. 创建 DMG（如果 create-dmg 可用）
if command -v create-dmg &> /dev/null; then
    echo "💿 创建 DMG 安装包..."
    create-dmg \
        --volname "${APP_NAME}" \
        --volicon "${APP_DIR}/Contents/Resources" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --app-drop-link 480 170 \
        --eula "${PROJECT_DIR}/EULA.txt" \
        "${DMG_NAME}" \
        "${APP_DIR}"
    echo "✅ DMG 已创建: ${DMG_NAME}"
else
    echo "⚠️  create-dmg 未安装，跳过 DMG 创建"
    echo "   安装命令: brew install create-dmg"
fi

echo "✅ 打包完成!"
echo ""
echo "📍 输出文件:"
echo "   - ${APP_DIR}"
if [ -f "${PROJECT_DIR}/${DMG_NAME}" ]; then
    echo "   - ${PROJECT_DIR}/${DMG_NAME}"
fi
echo ""
echo "💡 提示: 将 .app 移到 /Applications 目录即可安装"
