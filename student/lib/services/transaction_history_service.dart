import 'package:hive_flutter/hive_flutter.dart';

/// Service to track transaction IDs locally to prevent duplicate submissions
class TransactionHistoryService {
  static const String _boxName = 'transaction_history';
  static Box<String>? _box;

  /// Initialize the transaction history storage
  static Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<String>(_boxName);
    }
  }

  /// Check if a transaction ID has already been submitted from this device
  static Future<bool> isTransactionUsed(String transactionId) async {
    await initialize();
    final normalizedId = transactionId.trim().toUpperCase();
    return _box!.containsKey(normalizedId);
  }

  /// Record a transaction ID as used
  static Future<void> recordTransaction({
    required String transactionId,
    required String orderId,
    required double amount,
  }) async {
    await initialize();
    final normalizedId = transactionId.trim().toUpperCase();
    // Store with metadata as JSON string
    final metadata = '{"orderId":"$orderId","amount":$amount,"timestamp":"${DateTime.now().toIso8601String()}"}';
    await _box!.put(normalizedId, metadata);
  }

  /// Get all recorded transactions
  static Future<List<Map<String, dynamic>>> getAllTransactions() async {
    await initialize();
    final List<Map<String, dynamic>> transactions = [];
    for (final key in _box!.keys) {
      final value = _box!.get(key);
      if (value != null) {
        try {
          // Parse the JSON metadata
          final parts = value.replaceAll('{', '').replaceAll('}', '').replaceAll('"', '').split(',');
          transactions.add({
            'transactionId': key,
            'metadata': value,
          });
        } catch (_) {}
      }
    }
    return transactions;
  }

  /// Get transaction count
  static Future<int> getTransactionCount() async {
    await initialize();
    return _box!.length;
  }

  /// Clear old transactions (older than 30 days) to manage storage
  static Future<int> clearOldTransactions({int daysOld = 30}) async {
    await initialize();
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    int cleared = 0;
    
    final keysToRemove = <dynamic>[];
    for (final key in _box!.keys) {
      final value = _box!.get(key);
      if (value != null && value.contains('timestamp')) {
        try {
          final timestampMatch = RegExp(r'"timestamp":"([^"]+)"').firstMatch(value);
          if (timestampMatch != null) {
            final timestamp = DateTime.parse(timestampMatch.group(1)!);
            if (timestamp.isBefore(cutoffDate)) {
              keysToRemove.add(key);
            }
          }
        } catch (_) {}
      }
    }
    
    for (final key in keysToRemove) {
      await _box!.delete(key);
      cleared++;
    }
    
    return cleared;
  }
}
