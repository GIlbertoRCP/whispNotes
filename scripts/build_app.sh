#!/bin/bash
set -e

echo "========================================"
echo "  Building WhispNotes Release Package  "
echo "========================================"

# 1. Compile Swift executable in release mode
echo "==> Compiling Swift Release Binary..."
swift build -c release

BINARY_PATH=".build/release/swift-whispnotes"
if [ ! -f "$BINARY_PATH" ]; then
    echo "Error: Release binary not found at $BINARY_PATH"
    exit 1
fi

# 2. Setup Bundle Directory
APP_DIR="build/WhispNotes.app"
echo "==> Constructing $APP_DIR bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 3. Copy Executable, Info.plist, Icons, and PkgInfo
cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/WhispNotes"
chmod +x "$APP_DIR/Contents/MacOS/WhispNotes"

cp Info.plist "$APP_DIR/Contents/Info.plist"

if [ -f "assets/AppIcon.icns" ]; then
    cp assets/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "    - Included AppIcon.icns"
fi

echo "APPL????" > "$APP_DIR/Contents/PkgInfo"

# 4. Code Sign Bundle
echo "==> Code signing WhispNotes.app..."
if [ -f "WhispNotes.entitlements" ]; then
    codesign --force --deep --options runtime --entitlements WhispNotes.entitlements -s - "$APP_DIR"
else
    codesign --force --deep -s - "$APP_DIR"
fi

echo "==> Verifying signature..."
codesign -v --verbose "$APP_DIR"

# 5. Build DMG Package
echo "==> Packaging DMG Installer..."
DMG_STAGE="build/dmg_stage"
DMG_OUTPUT="build/WhispNotes-1.0.0.dmg"

rm -rf "$DMG_STAGE" "$DMG_OUTPUT"
mkdir -p "$DMG_STAGE"

cp -R "$APP_DIR" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

hdiutil create -volname "WhispNotes" -srcfolder "$DMG_STAGE" -ov -format UDZO "$DMG_OUTPUT"
rm -rf "$DMG_STAGE"

echo ""
echo "========================================"
echo "  Build & Packaging Completed Successfully! "
echo "  App Bundle : $APP_DIR"
echo "  DMG Output : $DMG_OUTPUT"
echo "========================================"
