import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/app_config.dart';
import '../models/print_order.dart';

/// Service for local storage using Hive
class StorageService {
  static Box<PrintOrder>? _pendingOrdersBox;
  static Box<StudentDetails>? _studentDetailsBox;
  static Box? _settingsBox;
  static bool _isInitialized = false;

  /// Initialize Hive and register adapters
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await Hive.initFlutter();
      
      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(SelectedFileAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PrintConfigAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(StudentDetailsAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(PaymentVerificationAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(PrintOrderAdapter());
      }
      
      // Open boxes with error recovery
      try {
        _pendingOrdersBox = await Hive.openBox<PrintOrder>(AppConfig.pendingOrdersBox);
      } catch (e) {
        if (kDebugMode) debugPrint('Corrupted pending orders box, deleting: $e');
        await Hive.deleteBoxFromDisk(AppConfig.pendingOrdersBox);
        _pendingOrdersBox = await Hive.openBox<PrintOrder>(AppConfig.pendingOrdersBox);
      }
      
      try {
        _studentDetailsBox = await Hive.openBox<StudentDetails>(AppConfig.studentDetailsBox);
      } catch (e) {
        if (kDebugMode) debugPrint('Corrupted student details box, deleting: $e');
        await Hive.deleteBoxFromDisk(AppConfig.studentDetailsBox);
        _studentDetailsBox = await Hive.openBox<StudentDetails>(AppConfig.studentDetailsBox);
      }
      
      try {
        _settingsBox = await Hive.openBox(AppConfig.settingsBox);
      } catch (e) {
        if (kDebugMode) debugPrint('Corrupted settings box, deleting: $e');
        await Hive.deleteBoxFromDisk(AppConfig.settingsBox);
        _settingsBox = await Hive.openBox(AppConfig.settingsBox);
      }
      
      _isInitialized = true;
      if (kDebugMode) debugPrint('StorageService initialized successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing StorageService: $e');
      rethrow;
    }
  }

  // ============================================
  // Pending Orders Methods
  // ============================================

  /// Add order to pending queue
  static Future<void> addPendingOrder(PrintOrder order) async {
    await _ensureInitialized();
    await _pendingOrdersBox!.put(order.orderId, order);
    if (kDebugMode) debugPrint('Added pending order: ${order.orderId}');
  }

  /// Update pending order
  static Future<void> updatePendingOrder(PrintOrder order) async {
    await _ensureInitialized();
    await _pendingOrdersBox!.put(order.orderId, order);
    if (kDebugMode) debugPrint('Updated pending order: ${order.orderId}');
  }

  /// Remove order from pending queue
  static Future<void> removePendingOrder(String orderId) async {
    await _ensureInitialized();
    await _pendingOrdersBox!.delete(orderId);
    if (kDebugMode) debugPrint('Removed pending order: $orderId');
  }

  /// Get all pending orders (FIFO order)
  static List<PrintOrder> getPendingOrders() {
    if (!_isInitialized || _pendingOrdersBox == null) return [];
    
    final orders = _pendingOrdersBox!.values.toList();
    // Sort by creation time (FIFO)
    orders.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return orders;
  }

  /// Get pending order by ID
  static PrintOrder? getPendingOrder(String orderId) {
    if (!_isInitialized || _pendingOrdersBox == null) return null;
    return _pendingOrdersBox!.get(orderId);
  }

  /// Get count of pending orders
  static int get pendingOrdersCount {
    if (!_isInitialized || _pendingOrdersBox == null) return 0;
    return _pendingOrdersBox!.length;
  }

  /// Check if there are pending orders
  static bool get hasPendingOrders => pendingOrdersCount > 0;

  /// Clear all pending orders
  static Future<void> clearAllPendingOrders() async {
    await _ensureInitialized();
    await _pendingOrdersBox!.clear();
    if (kDebugMode) debugPrint('Cleared all pending orders');
  }

  /// Get queue position for an order
  static int getQueuePosition(String orderId) {
    final orders = getPendingOrders();
    for (int i = 0; i < orders.length; i++) {
      if (orders[i].orderId == orderId) {
        return i + 1;
      }
    }
    return -1;
  }

  // ============================================
  // Student Details Methods
  // ============================================

  /// Save student details for later use
  static Future<void> saveStudentDetails(StudentDetails details) async {
    await _ensureInitialized();
    await _studentDetailsBox!.put('saved_student', details);
    if (kDebugMode) debugPrint('Saved student details: ${details.name}');
  }

  /// Get saved student details
  static StudentDetails? getSavedStudentDetails() {
    if (!_isInitialized || _studentDetailsBox == null) return null;
    return _studentDetailsBox!.get('saved_student');
  }

  /// Clear saved student details
  static Future<void> clearSavedStudentDetails() async {
    await _ensureInitialized();
    await _studentDetailsBox!.delete('saved_student');
    if (kDebugMode) debugPrint('Cleared saved student details');
  }

  // ============================================
  // Settings Methods
  // ============================================

  /// Save a setting
  static Future<void> saveSetting(String key, dynamic value) async {
    await _ensureInitialized();
    await _settingsBox!.put(key, value);
  }

  /// Get a setting
  static T? getSetting<T>(String key, {T? defaultValue}) {
    if (!_isInitialized || _settingsBox == null) return defaultValue;
    return _settingsBox!.get(key, defaultValue: defaultValue) as T?;
  }

  /// Check if dark mode is enabled
  static bool get isDarkMode => getSetting<bool>('dark_mode', defaultValue: true) ?? true;

  /// Set dark mode preference
  static Future<void> setDarkMode(bool value) async {
    await saveSetting('dark_mode', value);
  }

  // ============================================
  // Utility Methods
  // ============================================

  /// Ensure storage is initialized
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Close all boxes
  static Future<void> close() async {
    await _pendingOrdersBox?.close();
    await _studentDetailsBox?.close();
    await _settingsBox?.close();
    _isInitialized = false;
    if (kDebugMode) debugPrint('StorageService closed');
  }

  /// Get storage statistics
  static Map<String, dynamic> getStorageStats() {
    return {
      'pendingOrders': pendingOrdersCount,
      'hasSavedStudent': getSavedStudentDetails() != null,
      'isInitialized': _isInitialized,
    };
  }
}
