import '../config/app_config.dart';

/// Print Order Model
class PrintOrder {
  final String orderId;
  final String studentName;
  final String studentId;
  final String phone;
  final int totalPages;
  final String paperSize;
  final String printType;
  final String printSide;
  final int copies;
  final double totalCost;
  final String? transactionId;
  final double? paymentAmount;
  final String localFilePath;
  final DateTime receivedAt;
  final DateTime? completedAt;
  final OrderStatus status;
  final String? errorMessage;
  final String? fcmToken; // FCM token for push notifications

  PrintOrder({
    required this.orderId,
    required this.studentName,
    required this.studentId,
    required this.phone,
    required this.totalPages,
    required this.paperSize,
    required this.printType,
    required this.printSide,
    required this.copies,
    required this.totalCost,
    this.transactionId,
    this.paymentAmount,
    required this.localFilePath,
    required this.receivedAt,
    this.completedAt,
    this.status = OrderStatus.pending,
    this.errorMessage,
    this.fcmToken,
  });

  /// Create from WebSocket JSON payload
  factory PrintOrder.fromWebSocket(Map<String, dynamic> json, String localPath) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    final student = metadata['student'] as Map<String, dynamic>? ?? {};
    final config = metadata['config'] as Map<String, dynamic>? ?? {};
    final payment = metadata['payment'] as Map<String, dynamic>? ?? {};

    // totalPages is at metadata root level, not inside config
    final totalPages = metadata['totalPages'] ?? config['totalPages'] ?? 0;
    
    // FCM Token extraction with debug logging
    final fcmToken = metadata['fcm_token'] as String? ?? json['fcm_token'] as String?;
    print('=== FCM DEBUG [Order.fromWebSocket] ===');
    print('metadata[fcm_token]: ${metadata['fcm_token']}');
    print('json[fcm_token]: ${json['fcm_token']}');
    print('Final fcmToken: ${fcmToken != null ? "${fcmToken.substring(0, fcmToken.length > 50 ? 50 : fcmToken.length)}..." : "NULL"}');

    return PrintOrder(
      orderId: metadata['orderId'] ?? json['orderId'] ?? 'UNKNOWN',
      studentName: student['name'] ?? 'Unknown',
      studentId: student['studentId'] ?? '',
      phone: student['phone'] ?? '',
      totalPages: totalPages,
      paperSize: config['paperSize'] ?? 'A4',
      printType: config['printType'] ?? 'BW',
      printSide: config['printSide'] ?? 'SINGLE',
      copies: config['copies'] ?? 1,
      totalCost: (config['totalPrice'] ?? 0).toDouble(),
      transactionId: payment['transactionId'],
      paymentAmount: payment['amount']?.toDouble(),
      localFilePath: localPath,
      receivedAt: DateTime.now(),
      status: OrderStatus.pending,
      fcmToken: fcmToken,
    );
  }

  /// Create from database row
  factory PrintOrder.fromDatabase(Map<String, dynamic> row) {
    return PrintOrder(
      orderId: row['order_id'],
      studentName: row['student_name'],
      studentId: row['student_id'],
      phone: row['phone'],
      totalPages: row['total_pages'],
      paperSize: row['paper_size'],
      printType: row['print_type'],
      printSide: row['print_side'],
      copies: row['copies'],
      totalCost: row['total_cost'],
      transactionId: row['transaction_id'],
      paymentAmount: row['payment_amount'],
      localFilePath: row['local_file_path'],
      receivedAt: DateTime.parse(row['received_at']),
      completedAt: row['completed_at'] != null ? DateTime.parse(row['completed_at']) : null,
      status: OrderStatus.fromString(row['status']),
      errorMessage: row['error_message'],
      fcmToken: row['fcm_token'],
    );
  }

  /// Convert to database row
  Map<String, dynamic> toDatabase() {
    return {
      'order_id': orderId,
      'student_name': studentName,
      'student_id': studentId,
      'phone': phone,
      'total_pages': totalPages,
      'paper_size': paperSize,
      'print_type': printType,
      'print_side': printSide,
      'copies': copies,
      'total_cost': totalCost,
      'transaction_id': transactionId,
      'payment_amount': paymentAmount,
      'local_file_path': localFilePath,
      'received_at': receivedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'status': status.value,
      'error_message': errorMessage,
      'fcm_token': fcmToken,
    };
  }

  /// Create a copy with updated fields
  PrintOrder copyWith({
    OrderStatus? status,
    DateTime? completedAt,
    String? errorMessage,
    String? localFilePath,
  }) {
    return PrintOrder(
      orderId: orderId,
      studentName: studentName,
      studentId: studentId,
      phone: phone,
      totalPages: totalPages,
      paperSize: paperSize,
      printType: printType,
      printSide: printSide,
      copies: copies,
      totalCost: totalCost,
      transactionId: transactionId,
      paymentAmount: paymentAmount,
      localFilePath: localFilePath ?? this.localFilePath,
      receivedAt: receivedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Get print configuration summary
  String get configSummary {
    final sideText = printSide == 'DOUBLE' ? 'Double' : 'Single';
    final typeText = printType == 'COLOR' ? 'Color' : 'B&W';
    return '$paperSize • $typeText • $sideText • ${copies}x';
  }

  /// Check if payment is verified (based on transaction ID)
  bool get isVerified => transactionId != null && transactionId!.isNotEmpty;
}

/// Settings Model
class AppSettings {
  final String wsUrl;
  final String apiToken;  // API token for WebSocket authentication
  final String saveDirectory;
  final String? defaultPrinter;
  final bool autoPrint;
  final bool notificationSound;
  final bool autoStart;
  final bool minimizeToTray;

  AppSettings({
    required this.wsUrl,
    required this.apiToken,
    required this.saveDirectory,
    this.defaultPrinter,
    this.autoPrint = false,
    this.notificationSound = true,
    this.autoStart = false,
    this.minimizeToTray = true,
  });

  AppSettings copyWith({
    String? wsUrl,
    String? apiToken,
    String? saveDirectory,
    String? defaultPrinter,
    bool? autoPrint,
    bool? notificationSound,
    bool? autoStart,
    bool? minimizeToTray,
  }) {
    return AppSettings(
      wsUrl: wsUrl ?? this.wsUrl,
      apiToken: apiToken ?? this.apiToken,
      saveDirectory: saveDirectory ?? this.saveDirectory,
      defaultPrinter: defaultPrinter ?? this.defaultPrinter,
      autoPrint: autoPrint ?? this.autoPrint,
      notificationSound: notificationSound ?? this.notificationSound,
      autoStart: autoStart ?? this.autoStart,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
    );
  }
}

/// WebSocket Connection State
enum WsConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Earnings Summary
class EarningsSummary {
  final double today;
  final double thisWeek;
  final double thisMonth;
  final int ordersToday;
  final int ordersThisWeek;
  final int ordersThisMonth;

  EarningsSummary({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.ordersToday,
    required this.ordersThisWeek,
    required this.ordersThisMonth,
  });
}
