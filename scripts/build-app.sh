#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Port Manager"
BUILD_DIR=".build/release"
OUT_DIR="build"
APP_DIR="${OUT_DIR}/${APP_NAME}.app"

echo "Building release binary..."
swift build -c release

echo "Assembling ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/PortManager" "${APP_DIR}/Contents/MacOS/PortManager"
cp "Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
cp "Resources/MenuBarIcon.png" "${APP_DIR}/Contents/Resources/MenuBarIcon.png"

# Ad-hoc sign so Gatekeeper/launch services are happy running it locally.
codesign --force --deep --sign - "${APP_DIR}" >/dev/null 2>&1 || true

echo "Built: ${APP_DIR}"
echo "Run with: open \"${APP_DIR}\""
