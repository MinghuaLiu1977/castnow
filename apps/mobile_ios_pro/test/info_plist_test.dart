import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Info.plist Configuration Tests for Mobile iOS Pro', () {
    test('Info.plist contains UIBackgroundModes with audio and NSMicrophoneUsageDescription', () {
      final file = File('ios/Runner/Info.plist');
      expect(file.existsSync(), isTrue, reason: 'ios/Runner/Info.plist must exist');

      final content = file.readAsStringSync();

      expect(content.contains('<key>UIBackgroundModes</key>'), isTrue,
          reason: 'Info.plist must define UIBackgroundModes');
      expect(content.contains('<string>audio</string>'), isTrue,
          reason: 'Info.plist must include audio background mode for persistent audio capture during screen sharing');
      expect(content.contains('<key>NSMicrophoneUsageDescription</key>'), isTrue,
          reason: 'Info.plist must define NSMicrophoneUsageDescription');
    });
  });
}
