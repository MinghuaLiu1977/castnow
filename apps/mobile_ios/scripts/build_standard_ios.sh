#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$PROJECT_DIR")")"
IOS_DIR="$PROJECT_DIR/ios"
PROFILE_DIR="$ROOT_DIR/android_store/standard"
PBX_DIR="$IOS_DIR/Runner.xcodeproj"
ARCHIVE_PATH="$PROJECT_DIR/build/ios/archive/Runner-standard.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/ios/ipa-standard"
PLIST_PATH="$IOS_DIR/ExportOptions-standard.plist"
PODS_DIR="$IOS_DIR/Pods/Target Support Files/Pods-BroadcastExtension"

# Find the pods xcconfig for BroadcastExtension
BCAST_PODS_XCCONFIG=$(ls "$PODS_DIR/Pods-BroadcastExtension."*".xcconfig" 2>/dev/null | head -1)

cleanup() {
  if [ -n "$RUNNER_PLIST_BAK" ] && [ -f "$RUNNER_PLIST_BAK" ]; then
    cp "$RUNNER_PLIST_BAK" "$IOS_DIR/Runner/Info.plist"
    rm -f "$RUNNER_PLIST_BAK"
  fi
  if [ -n "$EXT_PLIST_BAK" ] && [ -f "$EXT_PLIST_BAK" ]; then
    cp "$EXT_PLIST_BAK" "$IOS_DIR/BroadcastExtension/Info.plist"
    rm -f "$EXT_PLIST_BAK"
  fi
  if [ -n "$RUNNER_ENT_BAK" ] && [ -f "$RUNNER_ENT_BAK" ]; then
    cp "$RUNNER_ENT_BAK" "$IOS_DIR/Runner/Runner.entitlements"
    rm -f "$RUNNER_ENT_BAK"
  fi
  if [ -n "$EXT_ENT_BAK" ] && [ -f "$EXT_ENT_BAK" ]; then
    cp "$EXT_ENT_BAK" "$IOS_DIR/BroadcastExtension/BroadcastExtension.entitlements"
    rm -f "$EXT_ENT_BAK"
  fi
  if [ -n "$EXT_PROF_ENT_BAK" ] && [ -f "$EXT_PROF_ENT_BAK" ]; then
    cp "$EXT_PROF_ENT_BAK" "$IOS_DIR/BroadcastExtension/BroadcastExtensionProfile.entitlements"
    rm -f "$EXT_PROF_ENT_BAK"
  fi
  if [ -n "$RELEASE_XCCONFIG_BAK" ] && [ -f "$RELEASE_XCCONFIG_BAK" ]; then
    cp "$RELEASE_XCCONFIG_BAK" "$IOS_DIR/Flutter/Release.xcconfig"
    rm -f "$RELEASE_XCCONFIG_BAK"
  fi
  if [ -n "$BCAST_XCCONFIG_BAK" ] && [ -f "$BCAST_XCCONFIG_BAK" ]; then
    cp "$BCAST_XCCONFIG_BAK" "$BCAST_PODS_XCCONFIG"
    rm -f "$BCAST_XCCONFIG_BAK"
  fi
  for bak in /tmp/Pods-BroadcastExtension.*.podsbak; do
    [ ! -f "$bak" ] && continue
    orig="$IOS_DIR/Pods/Target Support Files/Pods-BroadcastExtension/$(basename "$bak" .podsbak)"
    cp "$bak" "$orig" 2>/dev/null || true
    rm -f "$bak"
  done
  if [ -n "$APPICON_BAK_DIR" ] && [ -d "$APPICON_BAK_DIR" ]; then
    rm -rf "$APPICON_DIR"/*
    cp "$APPICON_BAK_DIR"/*.png "$APPICON_DIR/" 2>/dev/null || true
    cp "$APPICON_BAK_DIR"/Contents.json "$APPICON_DIR/" 2>/dev/null || true
    rm -rf "$APPICON_BAK_DIR"
  fi
  if [ -n "$PBXPROJ_BAK" ] && [ -f "$PBXPROJ_BAK" ]; then
    cp "$PBXPROJ_BAK" "$PBX_DIR/project.pbxproj"
    rm -f "$PBXPROJ_BAK"
  fi
  echo "[castnow] Cleanup complete."
}
trap cleanup EXIT

echo "=== CastNow Standard Flavor Build ==="
echo "Bundle ID: com.eastlakestudio.castnow"
echo "Display Name: CastNow"
echo ""

# Swap Info.plist files
RUNNER_PLIST_BAK=$(mktemp)
cp "$IOS_DIR/Runner/Info.plist" "$RUNNER_PLIST_BAK"
cp "$IOS_DIR/Runner/Info-standard.plist" "$IOS_DIR/Runner/Info.plist"

EXT_PLIST_BAK=$(mktemp)
cp "$IOS_DIR/BroadcastExtension/Info.plist" "$EXT_PLIST_BAK"
cp "$IOS_DIR/BroadcastExtension/Info-standard.plist" "$IOS_DIR/BroadcastExtension/Info.plist"

# Swap entitlements
RUNNER_ENT_BAK=$(mktemp)
cp "$IOS_DIR/Runner/Runner.entitlements" "$RUNNER_ENT_BAK"
cp "$IOS_DIR/Runner/Runner-standard.entitlements" "$IOS_DIR/Runner/Runner.entitlements"

EXT_ENT_BAK=$(mktemp)
cp "$IOS_DIR/BroadcastExtension/BroadcastExtension.entitlements" "$EXT_ENT_BAK"
cp "$IOS_DIR/BroadcastExtension/BroadcastExtension-standard.entitlements" "$IOS_DIR/BroadcastExtension/BroadcastExtension.entitlements"

if [ -f "$IOS_DIR/BroadcastExtension/BroadcastExtensionProfile.entitlements" ]; then
  EXT_PROF_ENT_BAK=$(mktemp)
  cp "$IOS_DIR/BroadcastExtension/BroadcastExtensionProfile.entitlements" "$EXT_PROF_ENT_BAK"
  cp "$IOS_DIR/BroadcastExtension/BroadcastExtension-standard.entitlements" "$IOS_DIR/BroadcastExtension/BroadcastExtensionProfile.entitlements"
fi

# Swap pbxproj to standard (no InAppPurchase capability)
PBXPROJ_BAK=$(mktemp)
cp "$PBX_DIR/project.pbxproj" "$PBXPROJ_BAK"
cp "$PBX_DIR/project_standard.pbxproj" "$PBX_DIR/project.pbxproj"

# Swap Release.xcconfig for standard bundle ID
RELEASE_XCCONFIG_BAK=$(mktemp)
cp "$IOS_DIR/Flutter/Release.xcconfig" "$RELEASE_XCCONFIG_BAK"
cat > "$IOS_DIR/Flutter/Release.xcconfig" << 'XCCONFIG'
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"
#include "Generated.xcconfig"
APP_BUNDLE_ID = com.eastlakestudio.castnow
XCCONFIG

# Swap AppIcon with standard (home-screen styled) icons
APPICON_DIR="$IOS_DIR/Runner/Assets.xcassets/AppIcon.appiconset"
APPICON_STANDARD_DIR="$IOS_DIR/Runner/Assets.xcassets/AppIcon-standard.appiconset"
if [ -d "$APPICON_STANDARD_DIR" ]; then
  APPICON_BAK_DIR=$(mktemp -d)
  cp "$APPICON_DIR"/*.png "$APPICON_BAK_DIR/" 2>/dev/null || true
  cp "$APPICON_DIR"/Contents.json "$APPICON_BAK_DIR/" 2>/dev/null || true
  rm -f "$APPICON_DIR"/*.png
  cp "$APPICON_STANDARD_DIR"/*.png "$APPICON_DIR/"
  cp "$APPICON_STANDARD_DIR"/Contents.json "$APPICON_DIR/"
  echo "Swapped to standard app icon (home-screen style)"
fi

echo "Phase 1: Building Flutter Resources (standard flavor)..."
cd "$PROJECT_DIR"

# Temporarily remove RevenueCat dependencies from pubspec for standard build
# (objective_c.framework has simulator platform that App Store rejects)
_PUBSPEC_BAK=$(mktemp)
cp pubspec.yaml "$_PUBSPEC_BAK"
sed -i '' '/purchases_flutter/d' pubspec.yaml
sed -i '' '/purchases_ui_flutter/d' pubspec.yaml

# Remove main.dart and main_pro.dart so RC imports don't cause analysis errors
[ -f lib/main.dart ] && mv lib/main.dart lib/main.dart.bak
[ -f lib/main_pro.dart ] && mv lib/main_pro.dart lib/main_pro.dart.bak

flutter pub get

flutter build ios --release --no-codesign --dart-define=FLAVOR=standard -t lib/main_standard.dart

# Restore pubspec and main files
cp "$_PUBSPEC_BAK" pubspec.yaml && rm -f "$_PUBSPEC_BAK"
[ -f lib/main.dart.bak ] && mv lib/main.dart.bak lib/main.dart
[ -f lib/main_pro.dart.bak ] && mv lib/main_pro.dart.bak lib/main_pro.dart
flutter pub get

# Patch BroadcastExtension Pods xcconfig AFTER flutter build (pod install overwrites it)
echo "Patching BroadcastExtension bundle ID..."
for f in "$IOS_DIR/Pods/Target Support Files/Pods-BroadcastExtension"/*.xcconfig; do
  [ ! -f "$f" ] && continue
  cp "$f" "/tmp/$(basename "$f").podsbak"
  sed -i '' 's/BROADCAST_EXTENSION_BUNDLE_ID = .*/BROADCAST_EXTENSION_BUNDLE_ID = com.eastlakestudio.castnow.BroadcastExtension/' "$f"
done

echo ""
echo "Phase 2: Building Xcode Archive (Standard, Manual Signing)..."
rm -rf "$ARCHIVE_PATH"

# Install provisioning profiles
mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles/
if [ -d "$PROFILE_DIR" ]; then
  cp "$PROFILE_DIR"/*.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/ 2>/dev/null || true
  echo "Installed profiles from $PROFILE_DIR"
fi

xcodebuild archive \
    -workspace ios/Runner.xcworkspace \
    -scheme Runner \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGNING_ALLOWED=NO

echo ""
echo "Phase 3: Exporting IPA..."
mkdir -p "$EXPORT_PATH"

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$PLIST_PATH" \
    -allowProvisioningUpdates

echo ""
echo "=== IPA Export Success! (Standard Flavor) ==="
echo "Destination: $EXPORT_PATH"

for f in "$EXPORT_PATH"/*.ipa; do if [ -f "$f" ]; then mv "$f" "$EXPORT_PATH/castnow_mobile.ipa"; break; fi; done
ls -lh "$EXPORT_PATH"
