import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/order.dart';
import '../services/database_service.dart';
import '../services/websocket_service.dart';
import '../services/file_service.dart';
import '../services/print_service.dart';
import '../services/notification_api_service.dart';

// ============================================
// Settings Provider
// ============================================

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier()
      : super(AppSettings(
          wsUrl: AppConfig.defaultWsUrl,
          apiToken: '',  // Must be configured by user
          saveDirectory: AppConfig.defaultSaveDirectory,
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      wsUrl: prefs.getString('ws_url') ?? AppConfig.defaultWsUrl,
      apiToken: prefs.getString('api_token') ?? '',  // Loaded from secure storage
      saveDirectory: prefs.getString('save_directory') ?? AppConfig.defaultSaveDirectory,
      defaultPrinter: prefs.getString('default_printer'),
      autoPrint: prefs.getBool('auto_print') ?? false,
      notificationSound: prefs.getBool('notification_sound') ?? true,
      autoStart: prefs.getBool('auto_start') ?? false,
      minimizeToTray: prefs.getBool('minimize_to_tray') ?? true,
    );
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ws_url', newSettings.wsUrl);
    await prefs.setString('api_token', newSettings.apiToken);  // Save API token
    await prefs.setString('save_directory', newSettings.saveDirectory);
    if (newSettings.defaultPrinter != null) {
      await prefs.setString('default_printer', newSettings.defaultPrinter!);
    }
    await prefs.setBool('auto_print', newSettings.autoPrint);
    await prefs.setBool('notification_sound', newSettings.notificationSound);
    await prefs.setBool('auto_start', newSettings.autoStart);
    await prefs.setBool('minimize_to_tray', newSettings.minimizeToTray);
    state = newSettings;
  }

  Future<void> setWsUrl(String url) async {
    await updateSettings(state.copyWith(wsUrl: url));
  }

  Future<void> setApiToken(String token) async {
    await updateSettings(state.copyWith(apiToken: token));
  }

  Future<void> setSaveDirectory(String dir) async {
    await updateSettings(state.copyWith(saveDirectory: dir));
  }

  Future<void> setAutoPrint(bool value) async {
    await updateSettings(state.copyWith(autoPrint: value));
  }
}

// ============================================
// WebSocket Connection Provider
// ============================================

final wsServiceProvider = Provider<WebSocketService>((ref) {
  final settings = ref.watch(settingsProvider);
  return WebSocketService(
    wsUrl: settings.wsUrl,
    apiToken: settings.apiToken,  // Use token from settings
  );
});

final connectionStateProvider = StreamProvider<WsConnectionState>((ref) {
  final wsService = ref.watch(wsServiceProvider);
  return wsService.connectionStateStream;
});

// ============================================
// Service Pause Provider
// ============================================

final servicePausedProvider = StateNotifierProvider<ServicePauseNotifier, bool>((ref) {
  return ServicePauseNotifier();
});

class ServicePauseNotifier extends StateNotifier<bool> {
  ServicePauseNotifier() : super(false);

  Future<bool> togglePause(String baseUrl, String apiToken, bool shouldPause) async {
    try {
      final endpoint = shouldPause ? '/api/service/pause' : '/api/service/resume';
      final url = '$baseUrl$endpoint?token=$apiToken';
      
      final response = await http.post(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          state = shouldPause;
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error toggling pause: $e');
      return false;
    }
  }
}

// ============================================
// Orders Provider
// ============================================

final pendingOrdersProvider = StateNotifierProvider<OrdersNotifier, List<PrintOrder>>((ref) {
  return OrdersNotifier(ref);
});

final completedOrdersProvider = FutureProvider.family<List<PrintOrder>, OrderFilter?>((ref, filter) async {
  return await DatabaseService.getCompletedOrders(
    fromDate: filter?.fromDate,
    toDate: filter?.toDate,
    searchQuery: filter?.searchQuery,
  );
});

class OrderFilter {
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? searchQuery;

  OrderFilter({this.fromDate, this.toDate, this.searchQuery});
}

class OrdersNotifier extends StateNotifier<List<PrintOrder>> {
  final Ref _ref;
  StreamSubscription? _orderSubscription;

  OrdersNotifier(this._ref) : super([]) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Load pending orders from database
    final orders = await DatabaseService.getPendingOrders();
    state = orders;

    // Listen for new orders from WebSocket
    final wsService = _ref.read(wsServiceProvider);
    _orderSubscription = wsService.orderStream.listen(_handleNewOrder);
  }

  Future<void> _handleNewOrder(Map<String, dynamic> data) async {
    try {
      final metadata = data['metadata'] as Map<String, dynamic>?;
      final pdfBytes = data['pdfBytes'] as Uint8List?;

      if (metadata == null || pdfBytes == null) {
        print('Invalid order data received');
        return;
      }

      final orderId = metadata['orderId'] ?? 'UNKNOWN';

      // Check for duplicates
      if (await DatabaseService.orderExists(orderId)) {
        print('Duplicate order rejected: $orderId');
        return;
      }

      // Validate PDF
      if (!FileService.isValidPdf(pdfBytes)) {
        print('Invalid PDF received for order: $orderId');
        // TODO: Request retry from server
        return;
      }

      // Check disk space
      final settings = _ref.read(settingsProvider);
      if (await FileService.isDiskSpaceLow(settings.saveDirectory)) {
        print('Warning: Low disk space!');
        // TODO: Show notification
      }

      // Save PDF to disk
      final studentName = (metadata['student'] as Map<String, dynamic>?)?['name'] ?? 'Unknown';
      final filePath = await FileService.savePdf(
        pdfBytes: pdfBytes,
        orderId: orderId,
        studentName: studentName,
        saveDirectory: settings.saveDirectory,
      );

      // Create order and save to database
      final order = PrintOrder.fromWebSocket({'metadata': metadata}, filePath);
      await DatabaseService.insertOrder(order);

      // Update state
      state = [...state, order];

      // Auto-print if enabled
      if (settings.autoPrint) {
        await printOrder(order.orderId);
      }

      print('Order received and saved: $orderId');
    } catch (e) {
      print('Error handling new order: $e');
    }
  }

  Future<void> printOrder(String orderId) async {
    final orderIndex = state.indexWhere((o) => o.orderId == orderId);
    if (orderIndex < 0) return;

    final order = state[orderIndex];
    final settings = _ref.read(settingsProvider);

    // Update status to printing
    state = [
      ...state.sublist(0, orderIndex),
      order.copyWith(status: OrderStatus.printing),
      ...state.sublist(orderIndex + 1),
    ];

    final success = await PrintService.printPdf(
      filePath: order.localFilePath,
      printerName: settings.defaultPrinter,
      showDialog: settings.defaultPrinter == null,
    );

    if (success) {
      // Revert to pending (user will mark complete manually)
      state = [
        ...state.sublist(0, orderIndex),
        order.copyWith(status: OrderStatus.pending),
        ...state.sublist(orderIndex + 1),
      ];
    } else {
      state = [
        ...state.sublist(0, orderIndex),
        order.copyWith(status: OrderStatus.error, errorMessage: 'Print failed'),
        ...state.sublist(orderIndex + 1),
      ];
    }
  }

  Future<void> markComplete(String orderId) async {
    final orderIndex = state.indexWhere((o) => o.orderId == orderId);
    if (orderIndex < 0) return;

    final order = state[orderIndex];
    final completedAt = DateTime.now();
    final settings = _ref.read(settingsProvider);
    
    print('=== FCM DEBUG [markComplete] ===');
    print('Order ID: $orderId');
    print('FCM Token from order: ${order.fcmToken}');
    print('FCM Token is null: ${order.fcmToken == null}');
    print('FCM Token is empty: ${order.fcmToken?.isEmpty ?? true}');
    
    // First update status to completed (for history tracking if needed)
    await DatabaseService.updateOrderStatus(
      orderId,
      OrderStatus.completed,
      completedAt: completedAt,
    );

    // Send push notification to student
    bool notificationSent = false;
    if (order.fcmToken != null && order.fcmToken!.isNotEmpty) {
      final baseUrl = settings.wsUrl
          .replaceAll('wss://', 'https://')
          .replaceAll('/ws/xerox', '');
      
      print('Base URL for notification: $baseUrl');
      print('API Token present: ${settings.apiToken.isNotEmpty}');
      
      try {
        notificationSent = await NotificationApiService.sendPrintCompleteNotification(
          baseUrl: baseUrl,
          apiToken: settings.apiToken,
          orderId: orderId,
          fcmToken: order.fcmToken!,
          studentName: order.studentName,
          totalPages: order.totalPages,
        );
        print('Notification API call result: $notificationSent');
      } catch (e) {
        print('ERROR: Failed to send notification for order $orderId: $e');
      }
    } else {
      print('WARNING: Skipping notification - no FCM token available!');
    }

    // Delete local PDF file
    try {
      await FileService.deletePdf(order.localFilePath);
      print('Deleted file: ${order.localFilePath}');
    } catch (e) {
      print('Failed to delete file: $e');
    }

    // Delete from database
    await DatabaseService.deleteOrder(orderId);

    // Remove from pending list (UI state)
    state = state.where((o) => o.orderId != orderId).toList();
  }


  Future<void> deleteOrder(String orderId, {String reason = "Order was not processed"}) async {
    final order = state.firstWhere((o) => o.orderId == orderId);
    final settings = _ref.read(settingsProvider);
    
    // Send rejection notification to student before deleting
    if (order.fcmToken != null && order.fcmToken!.isNotEmpty) {
      final baseUrl = settings.wsUrl
          .replaceAll('wss://', 'https://')
          .replaceAll('/ws/xerox', '');
      
      print('Sending rejection notification for order $orderId');
      
      try {
        await NotificationApiService.sendPrintRejectedNotification(
          baseUrl: baseUrl,
          apiToken: settings.apiToken,
          orderId: orderId,
          fcmToken: order.fcmToken!,
          studentName: order.studentName,
          reason: reason,
        );
      } catch (e) {
        print('ERROR: Failed to send rejection notification for order $orderId: $e');
      }
    } else {
      print('WARNING: Skipping rejection notification - no FCM token available!');
    }

    // Delete file
    await FileService.deletePdf(order.localFilePath);

    // Delete from database
    await DatabaseService.deleteOrder(orderId);

    // Remove from state
    state = state.where((o) => o.orderId != orderId).toList();
  }

  Future<void> refresh() async {
    final orders = await DatabaseService.getPendingOrders();
    state = orders;
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }
}

// ============================================
// Earnings Provider
// ============================================

final earningsProvider = FutureProvider<EarningsSummary>((ref) async {
  return await DatabaseService.getEarningsSummary();
});
