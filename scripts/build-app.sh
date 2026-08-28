#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_NAME="where-ive-been"
APP_PATH="$PROJECT_DIR/dist/$APP_NAME.app"
CONTENTS_PATH="$APP_PATH/Contents"
ICON_SOURCE="$PROJECT_DIR/.build/$APP_NAME-1024.png"
ICONSET_PATH="$PROJECT_DIR/.build/$APP_NAME.iconset"

cd "$PROJECT_DIR"
swift build -c release

rm -rf "$APP_PATH"
mkdir -p "$CONTENTS_PATH/MacOS" "$CONTENTS_PATH/Resources"
cp "$PROJECT_DIR/.build/release/$APP_NAME" "$CONTENTS_PATH/MacOS/$APP_NAME"
RESOURCE_BUNDLE="$PROJECT_DIR/.build/release/where-ive-been_WhereIveBeen.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
    ditto "$RESOURCE_BUNDLE" "$CONTENTS_PATH/Resources/where-ive-been_WhereIveBeen.bundle"
fi

plutil -create xml1 "$CONTENTS_PATH/Info.plist"
plutil -insert CFBundleName -string "$APP_NAME" "$CONTENTS_PATH/Info.plist"
plutil -insert CFBundleDisplayName -string "$APP_NAME" "$CONTENTS_PATH/Info.plist"
plutil -insert CFBundleIdentifier -string "app.whereivebeen.mac" "$CONTENTS_PATH/Info.plist"
plutil -insert CFBundleExecutable -string "$APP_NAME" "$CONTENTS_PATH/Info.plist"
plutil -insert CFBundlePackageType -string "APPL" "$CONTENTS_PATH/Info.plist"
plutil -insert CFBundleShortVersionString -string "1.0" "$CONTENTS_PATH/Info.plist"
plutil -insert CFBundleVersion -string "1" "$CONTENTS_PATH/Info.plist"
plutil -insert LSMinimumSystemVersion -string "15.0" "$CONTENTS_PATH/Info.plist"
plutil -insert LSApplicationCategoryType -string "public.app-category.travel" "$CONTENTS_PATH/Info.plist"
plutil -insert NSHighResolutionCapable -bool true "$CONTENTS_PATH/Info.plist"
plutil -insert CFBundleDocumentTypes -json '[{"CFBundleTypeName":"Google Location History","CFBundleTypeRole":"Viewer","LSItemContentTypes":["public.json"]}]' "$CONTENTS_PATH/Info.plist"

swift "$PROJECT_DIR/scripts/make-icon.swift" "$ICON_SOURCE"
rm -rf "$ICONSET_PATH"
mkdir -p "$ICONSET_PATH"
for spec in "16:icon_16x16.png" "32:icon_16x16@2x.png" "32:icon_32x32.png" "64:icon_32x32@2x.png" "128:icon_128x128.png" "256:icon_128x128@2x.png" "256:icon_256x256.png" "512:icon_256x256@2x.png" "512:icon_512x512.png" "1024:icon_512x512@2x.png"; do
    size="${spec%%:*}"
    name="${spec##*:}"
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_PATH/$name" >/dev/null
done
iconutil -c icns "$ICONSET_PATH" -o "$CONTENTS_PATH/Resources/$APP_NAME.icns"
plutil -insert CFBundleIconFile -string "$APP_NAME" "$CONTENTS_PATH/Info.plist"
touch "$APP_PATH"
codesign --force --deep --sign - "$APP_PATH"

echo "$APP_PATH"
