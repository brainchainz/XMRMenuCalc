#!/bin/bash
# Build XMRMenuCalc using swiftc (no Xcode needed)
set -e

PROJ_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$PROJ_DIR/XMRMenuCalc"
BUILD_DIR="$PROJ_DIR/build"
APP_NAME="XMRMenuCalc"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

echo "=== Building $APP_NAME ==="

# Create build directories
mkdir -p "$BUILD_DIR"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# Copy resources
cp -r "$SRC_DIR/Assets.xcassets" "$APP_PATH/Contents/Resources/"
cp "$SRC_DIR/app_icon.icns" "$APP_PATH/Contents/Resources/"
# Also copy the raw PNG for direct loading fallback
cp "$SRC_DIR/xmr_logo.png" "$APP_PATH/Contents/Resources/"
cp "$SRC_DIR/Info.plist" "$APP_PATH/Contents/Info.plist"

# Compile Swift sources for arm64 (native) and x86_64 (Rosetta)
SWIFT_FILES=$(find "$SRC_DIR" -name "*.swift" | sort)

echo "Compiling (arm64): $SWIFT_FILES"

swiftc \
  $SWIFT_FILES \
  -o "$BUILD_DIR/$APP_NAME.arm64" \
  -target arm64-apple-macosx13.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework Foundation

swiftc \
  $SWIFT_FILES \
  -o "$BUILD_DIR/$APP_NAME.x86_64" \
  -target x86_64-apple-macosx13.0 \
  -framework SwiftUI \
  -framework AppKit \
  -framework Foundation

# Create universal binary
lipo -create "$BUILD_DIR/$APP_NAME.arm64" "$BUILD_DIR/$APP_NAME.x86_64" -output "$APP_PATH/Contents/MacOS/$APP_NAME"

# Clean up intermediate binaries
rm -f "$BUILD_DIR/$APP_NAME.arm64" "$BUILD_DIR/$APP_NAME.x86_64"

# Code sign (ad-hoc signature)
codesign --force --sign - "$APP_PATH"

echo ""
echo "=== Build complete: $APP_PATH ==="
echo "To run: open \"$APP_PATH\""
