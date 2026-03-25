import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../models/order.dart';

/// Database Service for local order persistence
class DatabaseService {
  static Database? _database;
  static bool _initialized = false;

  /// Initialize the database
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize FFI for desktop
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(appDir.path, 'XeroxManager', AppConfig.databaseName);

    // Ensure directory exists
    await Directory(path.dirname(dbPath)).create(recursive: true);

    _database = await openDatabase(
      dbPath,
      version: AppConfig.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    _initialized = true;
  }

  /// Create database tables
  static Future<void> _onCreate(Database db, int version) async {
    // Orders table
    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id TEXT UNIQUE NOT NULL,
        student_name TEXT NOT NULL,
        student_id TEXT,
        phone TEXT,
        total_pages INTEGER NOT NULL,
        paper_size TEXT NOT NULL,
        print_type TEXT NOT NULL,
        print_side TEXT NOT NULL,
        copies INTEGER NOT NULL,
        total_cost REAL NOT NULL,
        transaction_id TEXT,
        payment_amount REAL,
        local_file_path TEXT NOT NULL,
        received_at TEXT NOT NULL,
        completed_at TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        fcm_token TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_orders_status ON orders(status)
    ''');

    await db.execute('''
      CREATE INDEX idx_orders_received ON orders(received_at)
    ''');
    
    // Verified Transactions table (for fraud prevention)
    await db.execute('''
      CREATE TABLE verified_transactions (
        txn_id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        amount REAL NOT NULL,
        received_at TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_txn_received ON verified_transactions(received_at)
    ''');
    
    // Duplicate Attempts Audit Log
    await db.execute('''
      CREATE TABLE duplicate_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        txn_id TEXT NOT NULL,
        attempted_order_id TEXT NOT NULL,
        original_order_id TEXT NOT NULL,
        attempted_at TEXT NOT NULL,
        source_info TEXT
      )
    ''');
  }

  /// Upgrade database tables
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Upgrade to v2: Add fraud prevention tables
      await db.execute('''
        CREATE TABLE verified_transactions (
          txn_id TEXT PRIMARY KEY,
          order_id TEXT NOT NULL,
          amount REAL NOT NULL,
          received_at TEXT NOT NULL
        )
      ''');
      
      await db.execute('''
        CREATE INDEX idx_txn_received ON verified_transactions(received_at)
      ''');
      
      await db.execute('''
        CREATE TABLE duplicate_attempts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          txn_id TEXT NOT NULL,
          attempted_order_id TEXT NOT NULL,
          original_order_id TEXT NOT NULL,
          attempted_at TEXT NOT NULL,
          source_info TEXT
        )
      ''');
    }
  }

  static Database get db {
    if (_database == null) {
      throw Exception('Database not initialized. Call DatabaseService.initialize() first.');
    }
    return _database!;
  }

  // ============================================
  // Order CRUD Operations
  // ============================================

  /// Insert a new order
  static Future<int> insertOrder(PrintOrder order) async {
    return await db.insert(
      'orders',
      order.toDatabase(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Check if order exists (for duplicate detection)
  static Future<bool> orderExists(String orderId) async {
    final result = await db.query(
      'orders',
      where: 'order_id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Get all pending orders (FIFO order)
  static Future<List<PrintOrder>> getPendingOrders() async {
    final results = await db.query(
      'orders',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'received_at ASC',
    );
    return results.map((row) => PrintOrder.fromDatabase(row)).toList();
  }

  /// Get all completed orders
  static Future<List<PrintOrder>> getCompletedOrders({
    DateTime? fromDate,
    DateTime? toDate,
    String? searchQuery,
  }) async {
    String whereClause = "status = 'completed'";
    List<dynamic> whereArgs = [];

    if (fromDate != null) {
      whereClause += " AND completed_at >= ?";
      whereArgs.add(fromDate.toIso8601String());
    }

    if (toDate != null) {
      whereClause += " AND completed_at <= ?";
      whereArgs.add(toDate.toIso8601String());
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClause += " AND (order_id LIKE ? OR student_name LIKE ?)";
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
    }

    final results = await db.query(
      'orders',
      where: whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'completed_at DESC',
    );

    return results.map((row) => PrintOrder.fromDatabase(row)).toList();
  }

  /// Update order status
  static Future<void> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    DateTime? completedAt,
    String? errorMessage,
  }) async {
    final updates = <String, dynamic>{
      'status': status.value,
    };

    if (completedAt != null) {
      updates['completed_at'] = completedAt.toIso8601String();
    }

    if (errorMessage != null) {
      updates['error_message'] = errorMessage;
    }

    await db.update(
      'orders',
      updates,
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  /// Delete an order
  static Future<void> deleteOrder(String orderId) async {
    await db.delete(
      'orders',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  // ============================================
  // Earnings Calculations
  // ============================================

  /// Get earnings summary
  static Future<EarningsSummary> getEarningsSummary() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    Future<Map<String, dynamic>> getStats(DateTime from) async {
      final result = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(total_cost), 0) as total,
          COUNT(*) as count
        FROM orders 
        WHERE status = 'completed' AND completed_at >= ?
      ''', [from.toIso8601String()]);

      return result.first;
    }

    final todayStats = await getStats(todayStart);
    final weekStats = await getStats(weekStart);
    final monthStats = await getStats(monthStart);

    return EarningsSummary(
      today: (todayStats['total'] as num).toDouble(),
      thisWeek: (weekStats['total'] as num).toDouble(),
      thisMonth: (monthStats['total'] as num).toDouble(),
      ordersToday: todayStats['count'] as int,
      ordersThisWeek: weekStats['count'] as int,
      ordersThisMonth: monthStats['count'] as int,
    );
  }

  // ============================================
  // Fraud Prevention: Transaction Verification
  // ============================================

  /// Check if a transaction ID has already been processed
  /// Returns the original order ID if duplicate, null otherwise
  static Future<String?> isTransactionDuplicate(String txnId) async {
    final normalizedId = txnId.trim().toUpperCase();
    final result = await db.query(
      'verified_transactions',
      where: 'txn_id = ?',
      whereArgs: [normalizedId],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      return result.first['order_id'] as String?;
    }
    return null;
  }

  /// Record a verified transaction (call this BEFORE saving the order)
  static Future<bool> recordVerifiedTransaction({
    required String txnId,
    required String orderId,
    required double amount,
  }) async {
    final normalizedId = txnId.trim().toUpperCase();
    
    try {
      await db.insert(
        'verified_transactions',
        {
          'txn_id': normalizedId,
          'order_id': orderId,
          'amount': amount,
          'received_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return true;
    } catch (e) {
      // Duplicate key violation - transaction already exists
      return false;
    }
  }

  /// Log a duplicate attempt for audit purposes
  static Future<void> logDuplicateAttempt({
    required String txnId,
    required String attemptedOrderId,
    required String originalOrderId,
    String? sourceInfo,
  }) async {
    await db.insert(
      'duplicate_attempts',
      {
        'txn_id': txnId.trim().toUpperCase(),
        'attempted_order_id': attemptedOrderId,
        'original_order_id': originalOrderId,
        'attempted_at': DateTime.now().toIso8601String(),
        'source_info': sourceInfo,
      },
    );
  }

  /// Get all duplicate attempts for audit
  static Future<List<Map<String, dynamic>>> getDuplicateAttempts({
    DateTime? fromDate,
    int limit = 100,
  }) async {
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    
    if (fromDate != null) {
      whereClause = 'attempted_at >= ?';
      whereArgs.add(fromDate.toIso8601String());
    }
    
    return await db.query(
      'duplicate_attempts',
      where: whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'attempted_at DESC',
      limit: limit,
    );
  }

  /// Get fraud prevention statistics
  static Future<Map<String, dynamic>> getFraudStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: 7));
    
    final todayAttempts = await db.rawQuery('''
      SELECT COUNT(*) as count FROM duplicate_attempts 
      WHERE attempted_at >= ?
    ''', [todayStart.toIso8601String()]);
    
    final weekAttempts = await db.rawQuery('''
      SELECT COUNT(*) as count FROM duplicate_attempts 
      WHERE attempted_at >= ?
    ''', [weekStart.toIso8601String()]);
    
    final totalVerified = await db.rawQuery('''
      SELECT COUNT(*) as count FROM verified_transactions
    ''');
    
    return {
      'duplicateAttemptsToday': todayAttempts.first['count'] ?? 0,
      'duplicateAttemptsThisWeek': weekAttempts.first['count'] ?? 0,
      'totalVerifiedTransactions': totalVerified.first['count'] ?? 0,
    };
  }

  /// Close the database
  static Future<void> close() async {
    await _database?.close();
    _database = null;
    _initialized = false;
  }
}
