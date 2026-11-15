#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
MODE="${1:-run}"
APP_NAME="ClaudePocketChecker"
APP_BUNDLE="$ROOT_DIR/dist/Claude Pocket Checker.app"
mkdir -p "$ROOT_DIR/.build/cache" "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
python3 "$ROOT_DIR/script/make_icon.py" "$ROOT_DIR/docs/assets/icon.png" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/LICENSE" "$APP_BUNDLE/Contents/Resources/LICENSE.txt"
# Stop only this companion, never Claude Desktop.
/usr/bin/pkill -x "$APP_NAME" >/dev/null 2>&1 || true
CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/cache" swift build --disable-sandbox --cache-path "$ROOT_DIR/.build/cache" -Xswiftc -module-cache-path -Xswiftc "$ROOT_DIR/.build/cache"
BUILD_BINARY="$(swift build --show-bin-path --disable-sandbox --cache-path "$ROOT_DIR/.build/cache")/$APP_NAME"
cp "$BUILD_BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ClaudePocketChecker</string>
<key>CFBundleIdentifier</key><string>com.radeleon.ClaudePocketChecker</string>
<key>CFBundleName</key><string>Claude Pocket Checker</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleShortVersionString</key><string>0.2.2</string>
<key>CFBundleVersion</key><string>5</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
# Finder/File Provider may attach FinderInfo when the local app is opened.
# Remove only non-code Finder metadata from this generated bundle before signing.
/usr/bin/xattr -dr com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
/usr/bin/xattr -dr com.apple.ResourceFork "$APP_BUNDLE" 2>/dev/null || true
/usr/bin/codesign --force --sign - --identifier com.radeleon.ClaudePocketChecker "$APP_BUNDLE"
case "$MODE" in
  --build) ;;
  --probe) "$BUILD_BINARY" --probe ;;
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
  --verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 1; /usr/bin/pgrep -x "$APP_NAME" ;;
  --debug) /usr/bin/lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs|--telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "ClaudePocketChecker"' ;;
  *) echo 'Usage: build_and_run.sh [--build|--probe|--verify|--debug|--logs|--telemetry]' >&2; exit 2 ;;
esac
