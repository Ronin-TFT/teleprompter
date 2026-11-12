#!/bin/zsh
# 构建“口播提词器”通用版（Apple Silicon + Intel）App 与 DMG。
# 用法：./build_dmg.sh            临时签名
#       SIGN_IDENTITY="证书名" ./build_dmg.sh   使用自己的代码签名证书
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
NAME="口播提词器"
APP="$ROOT/dist/$NAME.app"
DMG="$ROOT/dist/Teleprompter.dmg"
BUILD="$ROOT/build"
export MACOSX_DEPLOYMENT_TARGET=13.0

rm -rf "$APP" "$DMG" "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD/AppIcon.iconset"

clang -arch arm64 -arch x86_64 -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET -fobjc-arc -O2 -Wall \
  mac/*.m -o "$APP/Contents/MacOS/Teleprompter" \
  -framework Cocoa -framework WebKit -framework Carbon
lipo -info "$APP/Contents/MacOS/Teleprompter"

cp mac/Info.plist "$APP/Contents/Info.plist"
cp web/app.html "$APP/Contents/Resources/app.html"

clang -fobjc-arc tools/make_icon.m -framework Cocoa -o "$BUILD/make_icon"
"$BUILD/make_icon" "$BUILD/icon.png"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$BUILD/icon.png" --out "$BUILD/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" "$BUILD/icon.png" --out "$BUILD/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
  echo "提示：未设置 SIGN_IDENTITY，使用临时签名。" >&2
fi
codesign --force --sign "$SIGN_IDENTITY" --identifier local.ronin.teleprompter "$APP"
codesign --verify --strict "$APP"

mkdir -p "$BUILD/dmg"
ditto "$APP" "$BUILD/dmg/$NAME.app"
ln -s /Applications "$BUILD/dmg/Applications"
hdiutil create -volname "$NAME" -srcfolder "$BUILD/dmg" -ov -format UDZO "$DMG" >/dev/null
echo "$DMG"
