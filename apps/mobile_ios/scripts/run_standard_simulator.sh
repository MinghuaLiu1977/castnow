#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
IOS_DIR="$PROJECT_DIR/ios"
PBX_DIR="$IOS_DIR/Runner.xcodeproj"
APPICON_DIR="$IOS_DIR/Runner/Assets.xcassets/AppIcon.appiconset"
APPICON_STANDARD_DIR="$IOS_DIR/Runner/Assets.xcassets/AppIcon-standard.appiconset"
PODS_DIR="$IOS_DIR/Pods/Target Support Files/Pods-BroadcastExtension"

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
  if [ -n "$DEBUG_XCCONFIG_BAK" ] && [ -f "$DEBUG_XCCONFIG_BAK" ]; then
    cp "$DEBUG_XCCONFIG_BAK" "$IOS_DIR/Flutter/Debug.xcconfig"
    rm -f "$DEBUG_XCCONFIG_BAK"
  fi
  if [ -n "$RELEASE_XCCONFIG_BAK" ] && [ -f "$RELEASE_XCCONFIG_BAK" ]; then
    cp "$RELEASE_XCCONFIG_BAK" "$IOS_DIR/Flutter/Release.xcconfig"
    rm -f "$RELEASE_XCCONFIG_BAK"
  fi
  if [ -n "$BCAST_XCCONFIG_BAK" ] && [ -f "$BCAST_XCCONFIG_BAK" ]; then
    cp "$BCAST_XCCONFIG_BAK" "$BCAST_PODS_XCCONFIG"
    rm -f "$BCAST_XCCONFIG_BAK"
  fi
  if [ -n "$PBXPROJ_BAK" ] && [ -f "$PBXPROJ_BAK" ]; then
    cp "$PBXPROJ_BAK" "$PBX_DIR/project.pbxproj"
    rm -f "$PBXPROJ_BAK"
  fi
  for bak in /tmp/Pods-BroadcastExtension.*.podsbak; do
    [ ! -f "$bak" ] && continue
    orig="$IOS_DIR/Pods/Target Support Files/Pods-BroadcastExtension/$(basename "$bak" .podsbak)"
    cp "$bak" "$orig" 2>/dev/null || true
    rm -f "$bak"
  done
  if [ -n "$APPICON_BAK_DIR" ] && [ -d "$APPICON_BAK_DIR" ]; then
    rm -rf "$APPICON_DIR"/*
    cp "$APPICON_BAK_DIR"/* "$APPICON_DIR/" 2>/dev/null || true
    rm -rf "$APPICON_BAK_DIR"
  fi
  echo ""
  echo "=== Restored Pro config files ==="
}
trap cleanup EXIT

echo "=== CastNow Standard - iOS Simulator ==="
echo "Bundle ID: com.eastlakestudio.castnow"
echo ""

# Swap Info.plist
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

# Swap pbxproj
PBXPROJ_BAK=$(mktemp)
cp "$PBX_DIR/project.pbxproj" "$PBXPROJ_BAK"
cp "$PBX_DIR/project_standard.pbxproj" "$PBX_DIR/project.pbxproj"

# Swap Debug.xcconfig
DEBUG_XCCONFIG_BAK=$(mktemp)
cp "$IOS_DIR/Flutter/Debug.xcconfig" "$DEBUG_XCCONFIG_BAK"
cat > "$IOS_DIR/Flutter/Debug.xcconfig" << 'XCCONFIG'
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
#include "Generated.xcconfig"
APP_BUNDLE_ID = com.eastlakestudio.castnow
XCCONFIG

# Swap Release.xcconfig
RELEASE_XCCONFIG_BAK=$(mktemp)
cp "$IOS_DIR/Flutter/Release.xcconfig" "$RELEASE_XCCONFIG_BAK"
cat > "$IOS_DIR/Flutter/Release.xcconfig" << 'XCCONFIG'
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"
#include "Generated.xcconfig"
APP_BUNDLE_ID = com.eastlakestudio.castnow
XCCONFIG

# Swap AppIcon
if [ -d "$APPICON_STANDARD_DIR" ]; then
  APPICON_BAK_DIR=$(mktemp -d)
  cp "$APPICON_DIR"/*.png "$APPICON_BAK_DIR/" 2>/dev/null || true
  cp "$APPICON_DIR"/Contents.json "$APPICON_BAK_DIR/" 2>/dev/null || true
  rm -f "$APPICON_DIR"/*.png
  cp "$APPICON_STANDARD_DIR"/*.png "$APPICON_DIR/"
  cp "$APPICON_STANDARD_DIR"/Contents.json "$APPICON_DIR/"
fi

echo "Config files swapped. Launching simulator..."
echo ""

cd "$PROJECT_DIR"
flutter run --debug --dart-define=FLAVOR=standard -t lib/main_standard.dart
