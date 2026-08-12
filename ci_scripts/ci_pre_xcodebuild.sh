#!/bin/sh
set -x
set -e

echo "==> CI_WORKSPACE=$CI_WORKSPACE"
pwd
ls -la "$CI_WORKSPACE" 2>/dev/null | head -20

export FLUTTER_HOME="$HOME/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"

echo "==> Checking Flutter..."
if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "Flutter not found, cloning stable..."
  git clone -q --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi

cd "$CI_WORKSPACE/apps/mobile_ios_standard" || find "$CI_WORKSPACE" -maxdepth 3 -name pubspec.yaml
pwd
flutter --version || true
flutter pub get

echo "==> ephemeral Packages after pub get:"
ls -la ios/Flutter/ephemeral/Packages/ 2>/dev/null || echo "NO ephemeral/Packages dir"

echo "==> Installing CocoaPods for the Runner workspace..."
if ! command -v pod >/dev/null 2>&1; then
  echo "CocoaPods not found, installing..."
  sudo gem install cocoapods --no-document || gem install cocoapods --no-document
fi
cd ios
pod install

echo "==> Final ephemeral Packages:"
ls -la Flutter/ephemeral/Packages/ 2>/dev/null || echo "NO Flutter/ephemeral/Packages after pod install"
echo "==> ci_pre_xcodebuild.sh done"