#!/bin/zsh

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

dist_dir="$project_root/dist"
app_bundle="$dist_dir/MenuSync for FreeFileSync.app"
zip_path="$dist_dir/MenuSync-for-FreeFileSync-0.1.0-beta.zip"
temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

rm -rf "$app_bundle"
rm -f "$zip_path"
mkdir -p "$app_bundle/Contents/MacOS"
mkdir -p "$app_bundle/Contents/Resources"
mkdir -p "$temporary_dir/module-cache-arm64"
mkdir -p "$temporary_dir/module-cache-x86_64"

swift_sources=(
  MenuSyncForFreeFileSync/App/*.swift
  MenuSyncForFreeFileSync/Models/*.swift
  MenuSyncForFreeFileSync/Services/*.swift
  MenuSyncForFreeFileSync/Views/*.swift
)

swiftc \
  -O \
  -parse-as-library \
  -swift-version 6 \
  -target arm64-apple-macosx14.0 \
  -module-cache-path "$temporary_dir/module-cache-arm64" \
  "${swift_sources[@]}" \
  -o "$temporary_dir/MenuSyncForFreeFileSync-arm64"

swiftc \
  -O \
  -parse-as-library \
  -swift-version 6 \
  -target x86_64-apple-macosx14.0 \
  -module-cache-path "$temporary_dir/module-cache-x86_64" \
  "${swift_sources[@]}" \
  -o "$temporary_dir/MenuSyncForFreeFileSync-x86_64"

lipo -create \
  "$temporary_dir/MenuSyncForFreeFileSync-arm64" \
  "$temporary_dir/MenuSyncForFreeFileSync-x86_64" \
  -output "$app_bundle/Contents/MacOS/MenuSyncForFreeFileSync"

xcrun actool \
  --compile "$app_bundle/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 14.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$temporary_dir/asset-info.plist" \
  MenuSyncForFreeFileSync/Resources/Assets.xcassets

cp Packaging/Info.plist "$app_bundle/Contents/Info.plist"
codesign --force --deep --sign - --options runtime "$app_bundle"
codesign --verify --deep --strict "$app_bundle"
plutil -lint "$app_bundle/Contents/Info.plist"

ditto -c -k --keepParent "$app_bundle" "$zip_path"

echo "Created: $app_bundle"
echo "Created: $zip_path"
