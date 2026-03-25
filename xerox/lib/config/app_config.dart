import 'dart:io';

/// Application Configuration
class AppConfig {
  // WebSocket Configuration
  static const String defaultWsUrl = 'wss://itsmrop-iem-print-gurukul.hf.space/ws/xerox';
  static const Duration reconnectInterval = Duration(seconds: 5);
  static const Duration pingInterval = Duration(seconds: 30);

  // Default Save Directories
  static String get defaultSaveDirectory {
    if (Platform.isWindows) {
      return 'C:\\XeroxOrders';
    } else if (Platform.isMacOS) {
      return '${Platform.environment['HOME']}/XeroxOrders';
    } else {
      return '/home/XeroxOrders';
    }
  }

  // File Naming
  static String generateFilename(String orderId, String studentName, DateTime timestamp) {
    final safeName = studentName.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
    final timeStr = '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}';
    return '${orderId}_${safeName}_$timeStr.pdf';
  }

  // Disk Space Warning Threshold (1GB in bytes)
  static const int diskSpaceWarningBytes = 1024 * 1024 * 1024;

  // Database
  static const String databaseName = 'xerox_orders.db';
  static const int databaseVersion = 2;

  // UI
  static const String appName = 'Xerox Manager';
  static const String appVersion = '1.0.0';
}

/// Order Status
enum OrderStatus {
  pending('pending', 'Pending'),
  printing('printing', 'Printing'),
  completed('completed', 'Completed'),
  error('error', 'Error');

  final String value;
  final String displayName;
  const OrderStatus(this.value, this.displayName);

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => OrderStatus.pending,
    );
  }
}
