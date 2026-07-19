#!/usr/bin/env bash
# Local build — ONLY works on a Mac with Xcode installed.
# Produces HairColorPro-unsigned.ipa in this folder.
# (On Windows you don't run this — the GitHub Actions cloud build does it for you.)
set -euo pipefail

command -v xcodegen >/dev/null 2>&1 || brew install xcodegen

xcodegen generate

xcodebuild \
  -project HairColorPro.xcodeproj \
  -scheme HairColorPro \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build

APP=$(find build/Build/Products/Release-iphoneos -maxdepth 1 -name "*.app" | head -1)
rm -rf Payload
mkdir -p Payload
cp -R "$APP" Payload/
zip -qr HairColorPro-unsigned.ipa Payload
echo "Done -> $(pwd)/HairColorPro-unsigned.ipa"
