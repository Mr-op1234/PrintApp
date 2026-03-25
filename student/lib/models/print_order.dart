import 'dart:convert';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import '../config/app_config.dart';

part 'print_order.g.dart';

/// Represents a PDF file selected for printing
@HiveType(typeId: 0)
class SelectedFile {
  @HiveField(0)
  final String name;
  
  @HiveField(1)
  final String path;
  
  @HiveField(2)
  final int sizeBytes;
  
  @HiveField(3)
  final int pageCount;
  
  @HiveField(4)
  final Uint8List? bytes;

  SelectedFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.pageCount,
    this.bytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'sizeBytes': sizeBytes,
    'pageCount': pageCount,
  };

  factory SelectedFile.fromJson(Map<String, dynamic> json) => SelectedFile(
    name: json['name'] as String,
    path: json['path'] as String,
    sizeBytes: json['sizeBytes'] as int,
    pageCount: json['pageCount'] as int,
  );
}

/// Print configuration settings
@HiveType(typeId: 1)
class PrintConfig {
  @HiveField(0)
  final String paperSize;
  
  @HiveField(1)
  final String printType;
  
  @HiveField(2)
  final String printSide;
  
  @HiveField(3)
  final int copies;
  
  @HiveField(4)
  final String bindingType; // NONE, SPIRAL, SOFT

  PrintConfig({
    this.paperSize = 'A4',
    this.printType = 'BW',
    this.printSide = 'SINGLE',
    this.copies = 1,
    this.bindingType = 'NONE',
  });

  PrintConfig copyWith({
    String? paperSize,
    String? printType,
    String? printSide,
    int? copies,
    String? bindingType,
  }) {
    return PrintConfig(
      paperSize: paperSize ?? this.paperSize,
      printType: printType ?? this.printType,
      printSide: printSide ?? this.printSide,
      copies: copies ?? this.copies,
      bindingType: bindingType ?? this.bindingType,
    );
  }

  /// Get price per unit (sheet for double-sided, page for single-sided)
  double getPricePerUnit() {
    return AppConfig.getPricePerUnit(paperSize, printType);
  }

  /// Get top sheet price - always B&W price
  double getTopSheetPrice() {
    return AppConfig.getTopSheetPrice(paperSize);
  }

  /// Check if top sheet is free (50+ pages)
  bool isTopSheetFree(int totalPages) {
    return totalPages >= AppConfig.topSheetFreeThreshold;
  }

  /// Get binding price
  double getBindingPrice() {
    if (bindingType == 'SPIRAL') return AppConfig.spiralBindingPrice;
    if (bindingType == 'SOFT') return AppConfig.softBindingPrice;
    return 0.0;
  }

  /// Calculate billable units from page count (document pages only)
  int calculateBillableUnits(int pageCount, {bool includeFrontPage = true}) {
    return AppConfig.calculateBillableUnits(pageCount, printSide, includeFrontPage: includeFrontPage);
  }

  /// Get total pages including front page
  int getTotalPagesWithFrontPage(int pageCount) {
    return pageCount + AppConfig.frontPageCount;
  }

  /// Calculate total price with new protocol:
  /// (documentPages × pricePerUnit × copies) + topSheet (1 per order, free for 50+) + binding
  double calculateTotalPrice(int totalPages, {bool includeFrontPage = true}) {
    return AppConfig.calculateTotalCost(
      pageCount: totalPages,
      paperSize: paperSize,
      printType: printType,
      printSide: printSide,
      copies: copies,
      bindingType: bindingType,
      includeFrontPage: includeFrontPage,
    );
  }

  /// Get price breakdown for display
  String getPriceBreakdown(int totalPages) {
    final billableUnits = calculateBillableUnits(totalPages, includeFrontPage: false);
    final pricePerUnit = getPricePerUnit();
    final topSheetPrice = getTopSheetPrice();
    final unitLabel = printSide == 'DOUBLE' ? 'sheets' : 'pages';
    final topSheetFree = isTopSheetFree(totalPages);
    
    String breakdown = '$billableUnits $unitLabel × ₹${pricePerUnit.toStringAsFixed(0)} × $copies copies';
    
    if (topSheetFree) {
      breakdown += ' + Top sheet FREE (50+ pages)';
    } else {
      breakdown += ' + Top sheet ₹${topSheetPrice.toStringAsFixed(0)}';
    }
    
    if (bindingType != 'NONE') {
      breakdown += ' + ${bindingType == 'SPIRAL' ? 'Spiral' : 'Soft'} ₹${getBindingPrice().toStringAsFixed(0)}';
    }
    
    return breakdown;
  }

  Map<String, dynamic> toJson() => {
    'paperSize': paperSize,
    'printType': printType,
    'printSide': printSide,
    'copies': copies,
    'bindingType': bindingType,
  };

  factory PrintConfig.fromJson(Map<String, dynamic> json) => PrintConfig(
    paperSize: json['paperSize'] as String? ?? 'A4',
    printType: json['printType'] as String? ?? 'BW',
    printSide: json['printSide'] as String? ?? 'SINGLE',
    copies: json['copies'] as int? ?? 1,
    bindingType: json['bindingType'] as String? ?? 'NONE',
  );
}


/// Student information
@HiveType(typeId: 2)
class StudentDetails {
  @HiveField(0)
  final String name;
  
  @HiveField(1)
  final String studentId;
  
  @HiveField(2)
  final String phone;
  
  @HiveField(3)
  final String email;
  
  @HiveField(4)
  final String additionalInfo; // Optional additional information

  StudentDetails({
    required this.name,
    required this.studentId,
    required this.phone,
    required this.email,
    this.additionalInfo = '',
  });

  bool get isValid =>
      name.isNotEmpty &&
      studentId.isNotEmpty &&
      phone.isNotEmpty &&
      phone.length >= 10;
      // Note: email and additionalInfo are optional for validation

  Map<String, dynamic> toJson() => {
    'name': name,
    'studentId': studentId,
    'phone': phone,
    'email': email,
    'additionalInfo': additionalInfo,
  };

  factory StudentDetails.fromJson(Map<String, dynamic> json) => StudentDetails(
    name: json['name'] as String? ?? '',
    studentId: json['studentId'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    additionalInfo: json['additionalInfo'] as String? ?? '',
  );

  factory StudentDetails.empty() => StudentDetails(
    name: '',
    studentId: '',
    phone: '',
    email: '',
    additionalInfo: '',
  );
}

/// Payment verification result
@HiveType(typeId: 3)
class PaymentVerification {
  @HiveField(0)
  final bool isVerified;
  
  @HiveField(1)
  final String? transactionId;
  
  @HiveField(2)
  final double? amount;
  
  @HiveField(3)
  final double confidenceScore;
  
  @HiveField(4)
  final String? rawText;
  
  @HiveField(5)
  final String? screenshotPath;
  
  @HiveField(6)
  final Uint8List? screenshotBytes;
  
  @HiveField(7)
  final String? failureMessage;

  PaymentVerification({
    required this.isVerified,
    this.transactionId,
    this.amount,
    required this.confidenceScore,
    this.rawText,
    this.screenshotPath,
    this.screenshotBytes,
    this.failureMessage,
  });

  // OCR removed - always verified if screenshot is provided
  bool get meetsThreshold => isVerified;

  Map<String, dynamic> toJson() => {
    'isVerified': isVerified,
    'transactionId': transactionId,
    'amount': amount,
    'confidenceScore': confidenceScore,
    'rawText': rawText,
    'screenshotPath': screenshotPath,
    'failureMessage': failureMessage,
  };

  factory PaymentVerification.fromJson(Map<String, dynamic> json) => PaymentVerification(
    isVerified: json['isVerified'] as bool? ?? false,
    transactionId: json['transactionId'] as String?,
    amount: (json['amount'] as num?)?.toDouble(),
    confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.0,
    rawText: json['rawText'] as String?,
    screenshotPath: json['screenshotPath'] as String?,
    failureMessage: json['failureMessage'] as String?,
  );

  factory PaymentVerification.failed() => PaymentVerification(
    isVerified: false,
    confidenceScore: 0.0,
  );
}

/// Complete print order
@HiveType(typeId: 4)
class PrintOrder {
  @HiveField(0)
  final String orderId;
  
  @HiveField(1)
  final List<SelectedFile> files;
  
  @HiveField(2)
  final PrintConfig config;
  
  @HiveField(3)
  final StudentDetails student;
  
  @HiveField(4)
  final PaymentVerification? payment;
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  final String status;
  
  @HiveField(7)
  final int retryCount;
  
  @HiveField(8)
  final String? errorMessage;
  
  @HiveField(9)
  final Uint8List? mergedPdfBytes;
  
  @HiveField(10)
  final String? frontPagePath;
  
  @HiveField(11)
  final DateTime? lastRetryAt;

  PrintOrder({
    required this.orderId,
    required this.files,
    required this.config,
    required this.student,
    this.payment,
    required this.createdAt,
    this.status = 'pending',
    this.retryCount = 0,
    this.errorMessage,
    this.mergedPdfBytes,
    this.frontPagePath,
    this.lastRetryAt,
  });

  int get totalPages => files.fold(0, (sum, file) => sum + file.pageCount);
  
  int get totalSize => files.fold(0, (sum, file) => sum + file.sizeBytes);
  
  double get totalPrice => config.calculateTotalPrice(totalPages);

  String get formattedTotalSize {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  PrintOrder copyWith({
    String? orderId,
    List<SelectedFile>? files,
    PrintConfig? config,
    StudentDetails? student,
    PaymentVerification? payment,
    DateTime? createdAt,
    String? status,
    int? retryCount,
    String? errorMessage,
    Uint8List? mergedPdfBytes,
    String? frontPagePath,
    DateTime? lastRetryAt,
  }) {
    return PrintOrder(
      orderId: orderId ?? this.orderId,
      files: files ?? this.files,
      config: config ?? this.config,
      student: student ?? this.student,
      payment: payment ?? this.payment,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      mergedPdfBytes: mergedPdfBytes ?? this.mergedPdfBytes,
      frontPagePath: frontPagePath ?? this.frontPagePath,
      lastRetryAt: lastRetryAt ?? this.lastRetryAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'files': files.map((f) => f.toJson()).toList(),
    'config': config.toJson(),
    'student': student.toJson(),
    'payment': payment?.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'status': status,
    'retryCount': retryCount,
    'errorMessage': errorMessage,
    'totalPages': totalPages,
    'totalPrice': totalPrice,
  };

  String toJsonString() => jsonEncode(toJson());

  factory PrintOrder.fromJson(Map<String, dynamic> json) => PrintOrder(
    orderId: json['orderId'] as String,
    files: (json['files'] as List).map((f) => SelectedFile.fromJson(f)).toList(),
    config: PrintConfig.fromJson(json['config']),
    student: StudentDetails.fromJson(json['student']),
    payment: json['payment'] != null ? PaymentVerification.fromJson(json['payment']) : null,
    createdAt: DateTime.parse(json['createdAt']),
    status: json['status'] as String? ?? 'pending',
    retryCount: json['retryCount'] as int? ?? 0,
    errorMessage: json['errorMessage'] as String?,
    lastRetryAt: json['lastRetryAt'] != null ? DateTime.parse(json['lastRetryAt']) : null,
  );
}

/// API Response model
class ApiResponse {
  final bool success;
  final String? message;
  final String? orderId;
  final Map<String, dynamic>? data;

  ApiResponse({
    required this.success,
    this.message,
    this.orderId,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) => ApiResponse(
    success: json['success'] as bool? ?? false,
    message: json['message'] as String?,
    orderId: json['orderId'] as String?,
    data: json['data'] as Map<String, dynamic>?,
  );
}
/// Server status
class ServerStatus {
  final bool isOnline;
  final bool isXeroxOnline;
  final bool isAcceptingOrders;
  final bool isPaused;
  final String? message;
  final DateTime? checkedAt;

  ServerStatus({
    required this.isOnline,
    this.isXeroxOnline = false,
    this.isAcceptingOrders = true,
    this.isPaused = false,
    this.message,
    this.checkedAt,
  });

  /// Check if service is available for new orders
  bool get canSubmitOrders => isOnline && isXeroxOnline && isAcceptingOrders;

  /// Get user-friendly status message
  String get statusMessage {
    if (!isOnline) return 'Server is offline';
    if (!isXeroxOnline) return 'Xerox is offline';
    if (isPaused) return 'Service is temporarily paused';
    if (!isAcceptingOrders) return 'Not accepting orders';
    return 'Ready to accept orders';
  }

  factory ServerStatus.offline() => ServerStatus(
    isOnline: false,
    isXeroxOnline: false,
    isAcceptingOrders: false,
    message: 'Server is offline',
    checkedAt: DateTime.now(),
  );

  factory ServerStatus.online() => ServerStatus(
    isOnline: true,
    isXeroxOnline: true,
    isAcceptingOrders: true,
    checkedAt: DateTime.now(),
  );
}
