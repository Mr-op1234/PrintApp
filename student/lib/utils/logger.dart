import 'package:flutter/foundation.dart';

/// Debug-only logger that only prints in debug mode.
/// In release builds, all logging is completely disabled.
void log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

/// Debug-only logger with a tag prefix
void logTagged(String tag, String message) {
  if (kDebugMode) {
    debugPrint('[$tag] $message');
  }
}
