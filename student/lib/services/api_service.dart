import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/print_order.dart';
import '../utils/platform_utils.dart';
import 'notification_service.dart';

/// Service for API communication with HuggingFace Space backend
class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiEndpoint,
      connectTimeout: AppConfig.connectionTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  /// Check server health/status
  static Future<ServerStatus> checkServerStatus() async {
    try {
      final response = await _dio.get(
        AppConfig.healthEndpoint,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>?;
        return ServerStatus(
          isOnline: true,
          isXeroxOnline: data?['xerox_online'] ?? false,
          isAcceptingOrders: data?['accepting_orders'] ?? false,
          isPaused: data?['paused'] ?? false,
          message: data?['xerox_online'] != true 
              ? 'Xerox is offline' 
              : (data?['paused'] == true ? 'Service is paused' : null),
          checkedAt: DateTime.now(),
        );
      }
      return ServerStatus.offline();
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('Server status check failed: ${e.message}');
      return ServerStatus.offline();
    } catch (e) {
      if (kDebugMode) debugPrint('Server status check error: $e');
      return ServerStatus.offline();
    }
  }

  /// Upload order to server
  /// On native: Sends merged PDF + metadata JSON
  /// On web: Sends raw files + metadata for server processing
  static Future<ApiResponse> uploadOrder(PrintOrder order) async {
    try {
      final formData = await _prepareFormData(order);
      
      final response = await _dio.post(
        AppConfig.uploadEndpoint,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            if (kDebugMode) debugPrint('Upload progress: ${(sent / total * 100).toStringAsFixed(1)}%');
          }
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.fromJson(response.data);
      }
      
      return ApiResponse(
        success: false,
        message: 'Server returned status ${response.statusCode}',
      );
    } on DioException catch (e) {
      String message = 'Network error';
      
      if (e.type == DioExceptionType.connectionTimeout) {
        message = 'Connection timeout';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        message = 'Response timeout';
      } else if (e.type == DioExceptionType.connectionError) {
        message = 'Connection failed';
      } else if (e.response != null) {
        message = e.response?.data?['message'] ?? 'Server error';
      }
      
      if (kDebugMode) debugPrint('Upload failed: $message');
      return ApiResponse(success: false, message: message);
    } catch (e) {
      if (kDebugMode) debugPrint('Upload error: $e');
      return ApiResponse(success: false, message: e.toString());
    }
  }

  /// Prepare form data based on platform
  static Future<FormData> _prepareFormData(PrintOrder order) async {
    if (PlatformUtils.shouldProcessLocally) {
      // Native platform: Send merged PDF and metadata
      return _prepareNativeFormData(order);
    } else {
      // Web platform: Send raw files for server processing
      return _prepareWebFormData(order);
    }
  }

  /// Prepare form data for native platforms (merged PDF + metadata)
  static Future<FormData> _prepareNativeFormData(PrintOrder order) async {
    final formData = FormData();
    
    // Add metadata JSON
    formData.fields.add(MapEntry('metadata', order.toJsonString()));
    formData.fields.add(MapEntry('platform', PlatformUtils.platformName));
    formData.fields.add(MapEntry('processing_mode', 'local'));
    
    // Add FCM token for push notifications
    final fcmToken = NotificationService().fcmToken;
    if (kDebugMode) {
      debugPrint('=== FCM DEBUG [Student App] ===');
      debugPrint('FCM Token available: ${fcmToken != null}');
      debugPrint('FCM Token (first 50 chars): ${fcmToken?.substring(0, fcmToken.length > 50 ? 50 : fcmToken.length) ?? "NULL"}...');
    }
    if (fcmToken != null && fcmToken.isNotEmpty) {
      formData.fields.add(MapEntry('fcm_token', fcmToken));
      if (kDebugMode) debugPrint('FCM Token ADDED to form data');
    } else {
      if (kDebugMode) debugPrint('WARNING: FCM Token is NULL or EMPTY - notifications will NOT work!');
    }
    
    // Add merged PDF if available
    if (order.mergedPdfBytes != null) {
      formData.files.add(MapEntry(
        'merged_pdf',
        MultipartFile.fromBytes(
          order.mergedPdfBytes!,
          filename: '${order.orderId}_merged.pdf',
          contentType: DioMediaType.parse('application/pdf'),
        ),
      ));
    }
    
    // Add payment screenshot if verified locally
    if (kDebugMode) {
      debugPrint('=== PAYMENT SCREENSHOT DEBUG ===');
      debugPrint('order.payment is null: ${order.payment == null}');
      debugPrint('order.payment.screenshotBytes is null: ${order.payment?.screenshotBytes == null}');
      debugPrint('order.payment.screenshotBytes length: ${order.payment?.screenshotBytes?.length ?? 0}');
    }
    if (order.payment?.screenshotBytes != null) {
      if (kDebugMode) debugPrint('Adding payment_screenshot to form data: ${order.payment!.screenshotBytes!.length} bytes');
      formData.files.add(MapEntry(
        'payment_screenshot',
        MultipartFile.fromBytes(
          order.payment!.screenshotBytes!,
          filename: 'payment_screenshot.jpg',
          contentType: DioMediaType.parse('image/jpeg'),
        ),
      ));
    } else {
      if (kDebugMode) debugPrint('WARNING: No payment screenshot bytes to send!');
    }
    
    return formData;
  }

  /// Prepare form data for web platform (raw files for server processing)
  static Future<FormData> _prepareWebFormData(PrintOrder order) async {
    final formData = FormData();
    
    // Add metadata JSON
    formData.fields.add(MapEntry('metadata', order.toJsonString()));
    formData.fields.add(MapEntry('platform', 'web'));
    formData.fields.add(MapEntry('processing_mode', 'server'));
    
    // Add raw PDF files
    for (int i = 0; i < order.files.length; i++) {
      final file = order.files[i];
      if (file.bytes != null) {
        formData.files.add(MapEntry(
          'documents',
          MultipartFile.fromBytes(
            file.bytes!,
            filename: file.name,
            contentType: DioMediaType.parse('application/pdf'),
          ),
        ));
      }
    }
    
    // Add payment screenshot for server-side OCR
    if (order.payment?.screenshotBytes != null) {
      formData.files.add(MapEntry(
        'payment_screenshot',
        MultipartFile.fromBytes(
          order.payment!.screenshotBytes!,
          filename: 'payment_screenshot.jpg',
          contentType: DioMediaType.parse('image/jpeg'),
        ),
      ));
    }
    
    // Add student details separately for server
    formData.fields.add(MapEntry('student_name', order.student.name));
    formData.fields.add(MapEntry('student_id', order.student.studentId));
    formData.fields.add(MapEntry('student_phone', order.student.phone));
    formData.fields.add(MapEntry('student_email', order.student.email));
    
    // Add print config
    formData.fields.add(MapEntry('paper_size', order.config.paperSize));
    formData.fields.add(MapEntry('print_type', order.config.printType));
    formData.fields.add(MapEntry('print_side', order.config.printSide));
    formData.fields.add(MapEntry('copies', order.config.copies.toString()));
    
    return formData;
  }

  /// Get order status from server
  static Future<ApiResponse> getOrderStatus(String orderId) async {
    try {
      final response = await _dio.get('${AppConfig.statusEndpoint}/$orderId');
      
      if (response.statusCode == 200) {
        return ApiResponse.fromJson(response.data);
      }
      
      return ApiResponse(success: false, message: 'Failed to get status');
    } catch (e) {
      if (kDebugMode) debugPrint('Get status error: $e');
      return ApiResponse(success: false, message: e.toString());
    }
  }

  /// Test FCM notification - sends a test push notification
  static Future<String> testNotification(String fcmToken) async {
    try {
      if (kDebugMode) {
        debugPrint('=== TEST NOTIFICATION DEBUG ===');
        debugPrint('Sending test notification request to backend');
        debugPrint('FCM Token: ${fcmToken.substring(0, 50)}...');
      }
      
      // Send as query parameter (GET request)
      final response = await _dio.get(
        '/test-notification',
        queryParameters: {'fcm_token': fcmToken},
      );
      
      if (kDebugMode) {
        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response data: ${response.data}');
      }
      
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['message'] ?? 'Success';
      }
      
      return 'Failed: ${response.statusCode}';
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('Test notification DioException: ${e.message}');
        debugPrint('Response: ${e.response?.data}');
      }
      return 'Error: ${e.response?.data ?? e.message}';
    } catch (e) {
      if (kDebugMode) debugPrint('Test notification error: $e');
      return 'Error: $e';
    }
  }
}
