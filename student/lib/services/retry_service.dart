import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../models/print_order.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Service for automatic retry of failed orders
class RetryService {
  static Timer? _retryTimer;
  static bool _isRetrying = false;
  static final StreamController<RetryStatus> _statusController = 
      StreamController<RetryStatus>.broadcast();

  /// Stream of retry status updates
  static Stream<RetryStatus> get statusStream => _statusController.stream;

  /// Start the automatic retry timer
  static void startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(
      AppConfig.retryInterval,
      (_) => _performRetry(),
    );
    if (kDebugMode) debugPrint('Retry timer started (every ${AppConfig.retryInterval.inSeconds}s)');
  }

  /// Stop the retry timer
  static void stopRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (kDebugMode) debugPrint('Retry timer stopped');
  }

  /// Check if retry timer is running
  static bool get isTimerActive => _retryTimer?.isActive ?? false;

  /// Perform retry of pending orders
  static Future<void> _performRetry() async {
    if (_isRetrying) {
      if (kDebugMode) debugPrint('Retry already in progress, skipping...');
      return;
    }

    final pendingOrders = StorageService.getPendingOrders();
    if (pendingOrders.isEmpty) {
      if (kDebugMode) debugPrint('No pending orders to retry');
      return;
    }

    _isRetrying = true;
    if (kDebugMode) debugPrint('RetryService: Starting auto-retry for ${pendingOrders.length} orders');
    _statusController.add(RetryStatus(
      isRetrying: true,
      currentOrderId: null,
      queueLength: pendingOrders.length,
      message: 'Checking server availability...',
    ));

    try {
      // Check server status first
      final serverStatus = await ApiService.checkServerStatus();
      if (kDebugMode) debugPrint('RetryService: Server status - online=${serverStatus.isOnline}, xerox=${serverStatus.isXeroxOnline}, accepting=${serverStatus.isAcceptingOrders}');
      
      if (!serverStatus.isOnline) {
        if (kDebugMode) debugPrint('Server offline, skipping retry');
        _statusController.add(RetryStatus(
          isRetrying: false,
          currentOrderId: null,
          queueLength: pendingOrders.length,
          message: 'Server offline, will retry later',
        ));
        return;
      }

      if (!serverStatus.isXeroxOnline) {
        if (kDebugMode) debugPrint('Xerox offline, skipping retry');
        _statusController.add(RetryStatus(
          isRetrying: false,
          currentOrderId: null,
          queueLength: pendingOrders.length,
          message: 'Xerox is offline, will retry later',
        ));
        return;
      }

      if (!serverStatus.isAcceptingOrders) {
        if (kDebugMode) debugPrint('Server not accepting orders');
        _statusController.add(RetryStatus(
          isRetrying: false,
          currentOrderId: null,
          queueLength: pendingOrders.length,
          message: 'Server not accepting orders',
        ));
        return;
      }

      // Process orders in FIFO order
      for (int i = 0; i < pendingOrders.length; i++) {
        final order = pendingOrders[i];
        
        // Skip if max retries exceeded
        if (order.retryCount >= AppConfig.maxRetries) {
          if (kDebugMode) debugPrint('Max retries exceeded for ${order.orderId}');
          continue;
        }

        _statusController.add(RetryStatus(
          isRetrying: true,
          currentOrderId: order.orderId,
          currentPosition: i + 1,
          queueLength: pendingOrders.length,
          message: 'Uploading order ${i + 1}/${pendingOrders.length}...',
        ));

        // Attempt upload
        final result = await ApiService.uploadOrder(order);

        if (result.success) {
          if (kDebugMode) debugPrint('Order ${order.orderId} uploaded successfully');
          await StorageService.removePendingOrder(order.orderId);
          
          _statusController.add(RetryStatus(
            isRetrying: true,
            currentOrderId: order.orderId,
            queueLength: pendingOrders.length - 1,
            message: 'Order uploaded successfully!',
            lastSuccessfulOrderId: order.orderId,
          ));
        } else {
          if (kDebugMode) debugPrint('Order ${order.orderId} failed: ${result.message}');
          
          // Update retry count
          final updatedOrder = order.copyWith(
            retryCount: order.retryCount + 1,
            lastRetryAt: DateTime.now(),
            errorMessage: result.message,
            status: 'queued',
          );
          await StorageService.updatePendingOrder(updatedOrder);
          
          _statusController.add(RetryStatus(
            isRetrying: true,
            currentOrderId: order.orderId,
            queueLength: pendingOrders.length,
            message: 'Failed: ${result.message}',
          ));
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Retry error: $e');
      _statusController.add(RetryStatus(
        isRetrying: false,
        message: 'Error: $e',
      ));
    } finally {
      _isRetrying = false;
      _statusController.add(RetryStatus(
        isRetrying: false,
        queueLength: StorageService.pendingOrdersCount,
        message: StorageService.hasPendingOrders 
            ? 'Will retry in ${AppConfig.retryInterval.inSeconds}s' 
            : 'All orders processed',
      ));
    }
  }

  /// Manually trigger retry
  static Future<void> retryNow() async {
    await _performRetry();
  }

  /// Retry a specific order
  static Future<bool> retrySingleOrder(String orderId) async {
    if (kDebugMode) debugPrint('RetryService: Starting single order retry for $orderId');
    
    final order = StorageService.getPendingOrder(orderId);
    if (order == null) {
      if (kDebugMode) debugPrint('RetryService: Order $orderId not found in storage!');
      return false;
    }
    
    if (kDebugMode) {
      debugPrint('RetryService: Order found. mergedPdfBytes: ${order.mergedPdfBytes?.length ?? 0} bytes');
      debugPrint('RetryService: Files: ${order.files.length}');
      for (int i = 0; i < order.files.length; i++) {
        debugPrint('RetryService: File $i bytes: ${order.files[i].bytes?.length ?? 0}');
      }
    }

    _statusController.add(RetryStatus(
      isRetrying: true,
      currentOrderId: orderId,
      message: 'Retrying order...',
    ));

    // Check server status first
    final serverStatus = await ApiService.checkServerStatus();
    if (kDebugMode) debugPrint('RetryService: Server status - online=${serverStatus.isOnline}, xerox=${serverStatus.isXeroxOnline}, accepting=${serverStatus.isAcceptingOrders}');
    
    if (!serverStatus.canSubmitOrders) {
      final errorMsg = serverStatus.statusMessage ?? 'Cannot submit orders';
      if (kDebugMode) debugPrint('RetryService: Cannot submit - $errorMsg');
      final updatedOrder = order.copyWith(
        retryCount: order.retryCount + 1,
        lastRetryAt: DateTime.now(),
        errorMessage: errorMsg,
      );
      await StorageService.updatePendingOrder(updatedOrder);
      _statusController.add(RetryStatus(
        isRetrying: false,
        message: 'Failed: $errorMsg',
      ));
      return false;
    }
    
    if (kDebugMode) debugPrint('RetryService: Uploading order...');
    final result = await ApiService.uploadOrder(order);
    if (kDebugMode) debugPrint('RetryService: Upload result - success=${result.success}, message=${result.message}');

    if (result.success) {
      await StorageService.removePendingOrder(orderId);
      _statusController.add(RetryStatus(
        isRetrying: false,
        lastSuccessfulOrderId: orderId,
        message: 'Order uploaded successfully!',
      ));
      return true;
    } else {
      final updatedOrder = order.copyWith(
        retryCount: order.retryCount + 1,
        lastRetryAt: DateTime.now(),
        errorMessage: result.message,
      );
      await StorageService.updatePendingOrder(updatedOrder);
      _statusController.add(RetryStatus(
        isRetrying: false,
        message: 'Failed: ${result.message}',
      ));
      return false;
    }
  }

  /// Cancel a pending order
  static Future<void> cancelOrder(String orderId) async {
    await StorageService.removePendingOrder(orderId);
    _statusController.add(RetryStatus(
      isRetrying: false,
      queueLength: StorageService.pendingOrdersCount,
      message: 'Order cancelled',
    ));
  }

  /// Dispose resources
  static void dispose() {
    stopRetryTimer();
    _statusController.close();
  }
}

/// Status of retry operations
class RetryStatus {
  final bool isRetrying;
  final String? currentOrderId;
  final int? currentPosition;
  final int? queueLength;
  final String? message;
  final String? lastSuccessfulOrderId;

  RetryStatus({
    required this.isRetrying,
    this.currentOrderId,
    this.currentPosition,
    this.queueLength,
    this.message,
    this.lastSuccessfulOrderId,
  });
}
