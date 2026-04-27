#!/bin/bash
# Build script for XMRMenuCalc Linux
# Usage: ./build.sh [output_name]
set -e

OUTPUT="${1:-xmrmencalc}"

echo "=== Building XMRMenuCalc for Linux ==="
echo "Output: $OUTPUT"

go build -ldflags="-s -w" -o "$OUTPUT"

echo ""
echo "=== Build complete ==="
echo "Binary: $OUTPUT"
echo ""
echo "Run: ./$OUTPUT"
echo "Requires: X11 or Wayland display server"
