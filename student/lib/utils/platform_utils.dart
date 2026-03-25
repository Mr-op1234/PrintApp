import 'package:flutter/foundation.dart';

/// Platform detection utilities for routing processing logic
class PlatformUtils {
  /// Check if running on web platform
  static bool get isWeb => kIsWeb;

  /// Check if running on mobile platforms (Android/iOS)
  static bool get isMobile => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS);

  /// Check if running on desktop platforms (Windows/macOS/Linux)
  static bool get isDesktop => !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux);

  /// Check if running on native platforms (mobile + desktop)
  static bool get isNative => !kIsWeb;

  /// Check if local processing should be used
  /// On native platforms: process locally (PDF operations, OCR, merging)
  /// On web: send to server for processing
  static bool get shouldProcessLocally => isNative;

  /// Check if OCR is supported locally
  /// Mobile: ML Kit, Desktop: Tesseract
  static bool get supportsLocalOcr => isMobile || isDesktop;

  /// Get platform name for display
  static String get platformName {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      default:
        return 'Unknown';
    }
  }

  /// Get processing mode description
  static String get processingModeDescription {
    if (shouldProcessLocally) {
      return 'Local processing mode - PDF operations run on device';
    }
    return 'Cloud processing mode - Files sent to server';
  }
}
