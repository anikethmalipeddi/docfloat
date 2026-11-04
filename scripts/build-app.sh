#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
BUILD_DIR="$ROOT/.build/release"
APP_DIR="$ROOT/dist/DocFloat.app"

cd "$ROOT"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/DocFloat" "$APP_DIR/Contents/MacOS/DocFloat"
cp "$ROOT/resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT/resources/DocFloat.icns" "$APP_DIR/Contents/Resources/DocFloat.icns"

SIGN_IDENTITY="${DOCFLOAT_SIGN_IDENTITY:--}"
if [[ -z "${DOCFLOAT_SIGN_IDENTITY:-}" && -f "$ROOT/.signing-identity" ]]; then
  SIGN_IDENTITY="$(< "$ROOT/.signing-identity")"
fi
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
echo "Built $APP_DIR"
