#!/bin/sh
set -e

# Xcode Cloud uses $CI_WORKSPACE as the repo root.
# This project lives under apps/mobile_ios_standard.
export FLUTTER_HOME="$HOME/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"

echo "==> Checking Flutter..."
if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  echo "Flutter not found, cloning stable..."
  git clone -q --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi

cd "$CI_WORKSPACE/apps/mobile_ios_standard"
flutter --version
flutter pub get

echo "==> Installing CocoaPods for the Runner workspace..."
if ! command -v pod >/dev/null 2>&1; then
  echo "CocoaPods not found, installing..."
  sudo gem install cocoapods --no-document
fi
cd ios
pod install
echo "==> ci_pre_xcodebuild.sh done"