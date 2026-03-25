import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for triggering push notifications via the backend
class NotificationApiService {
  /// Send print complete notification to student
  /// Returns true if notification was sent successfully
  static Future<bool> sendPrintCompleteNotification({
    required String baseUrl,
    required String apiToken,
    required String orderId,
    required String fcmToken,
    required String studentName,
    required int totalPages,
  }) async {
    debugPrint('=== FCM DEBUG [NotificationApiService] ===');
    debugPrint('Base URL: $baseUrl');
    debugPrint('Order ID: $orderId');
    debugPrint('FCM Token (first 50): ${fcmToken.substring(0, fcmToken.length > 50 ? 50 : fcmToken.length)}...');
    debugPrint('Student: $studentName, Pages: $totalPages');
    
    if (fcmToken.isEmpty) {
      debugPrint('ERROR: No FCM token available for order $orderId');
      return false;
    }

    try {
      final url = Uri.parse('$baseUrl/api/notify/complete?token=$apiToken');
      debugPrint('Calling URL: $url');
      
      final response = await http.post(
        url,
        body: {
          'order_id': orderId,
          'fcm_token': fcmToken,
          'student_name': studentName,
          'total_pages': totalPages.toString(),
        },
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('SUCCESS: Notification sent for order $orderId');
          return true;
        } else {
          debugPrint('FAILED: Server returned success=false: ${data['message']}');
        }
      } else {
        debugPrint('FAILED: HTTP ${response.statusCode}');
      }
      
      return false;
    } catch (e) {
      debugPrint('ERROR sending notification: $e');
      return false;
    }
  }

  /// Send print rejected notification to student
  /// Returns true if notification was sent successfully
  static Future<bool> sendPrintRejectedNotification({
    required String baseUrl,
    required String apiToken,
    required String orderId,
    required String fcmToken,
    required String studentName,
    String reason = "Order was not processed",
  }) async {
    debugPrint('=== FCM DEBUG [NotificationApiService - Rejection] ===');
    debugPrint('Base URL: $baseUrl');
    debugPrint('Order ID: $orderId');
    debugPrint('FCM Token (first 50): ${fcmToken.substring(0, fcmToken.length > 50 ? 50 : fcmToken.length)}...');
    debugPrint('Student: $studentName, Reason: $reason');
    
    if (fcmToken.isEmpty) {
      debugPrint('ERROR: No FCM token available for order $orderId');
      return false;
    }

    try {
      final url = Uri.parse('$baseUrl/api/notify/rejected?token=$apiToken');
      debugPrint('Calling URL: $url');
      
      final response = await http.post(
        url,
        body: {
          'order_id': orderId,
          'fcm_token': fcmToken,
          'student_name': studentName,
          'reason': reason,
        },
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('SUCCESS: Rejection notification sent for order $orderId');
          return true;
        } else {
          debugPrint('FAILED: Server returned success=false: ${data['message']}');
        }
      } else {
        debugPrint('FAILED: HTTP ${response.statusCode}');
      }
      
      return false;
    } catch (e) {
      debugPrint('ERROR sending rejection notification: $e');
      return false;
    }
  }
}
