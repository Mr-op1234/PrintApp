import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/print_order.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/retry_service.dart';
import '../services/pdf_service.dart';
// OCR removed - screenshots sent directly to Xerox Manager
import '../utils/helpers.dart';

// ============================================
// Server Status Provider
// ============================================

/// Holds the current server status
final serverStatusProvider = StateNotifierProvider<ServerStatusNotifier, ServerStatus>(
  (ref) => ServerStatusNotifier(),
);

class ServerStatusNotifier extends StateNotifier<ServerStatus> {
  Timer? _refreshTimer;

  ServerStatusNotifier() : super(ServerStatus.offline()) {
    _startRefreshTimer();
    checkStatus();
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkStatus(),
    );
  }

  Future<void> checkStatus() async {
    state = await ApiService.checkServerStatus();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

// ============================================
// Pending Orders Provider
// ============================================

/// Holds the list of pending orders
final pendingOrdersProvider = StateNotifierProvider<PendingOrdersNotifier, List<PrintOrder>>(
  (ref) => PendingOrdersNotifier(),
);

class PendingOrdersNotifier extends StateNotifier<List<PrintOrder>> {
  PendingOrdersNotifier() : super([]) {
    // Load orders immediately on creation (constructor is safe)
    state = StorageService.getPendingOrders();
  }

  void _updateStateSafe() {
    // Use Future.delayed(Duration.zero) to ensure we're in a completely new
    // event loop iteration, separate from any widget builds
    Future.delayed(Duration.zero, () {
      if (mounted) {
        state = StorageService.getPendingOrders();
      }
    });
  }

  void refresh() {
    // Safe refresh - defers if needed
    _updateStateSafe();
  }
  
  void refreshSync() {
    // Only use when explicitly called from user action (not during async callbacks)
    state = StorageService.getPendingOrders();
  }

  Future<void> addOrder(PrintOrder order) async {
    await StorageService.addPendingOrder(order);
    _updateStateSafe();
  }

  Future<void> removeOrder(String orderId) async {
    await StorageService.removePendingOrder(orderId);
    _updateStateSafe();
  }

  Future<void> updateOrder(PrintOrder order) async {
    await StorageService.updatePendingOrder(order);
    _updateStateSafe();
  }

  int getQueuePosition(String orderId) {
    for (int i = 0; i < state.length; i++) {
      if (state[i].orderId == orderId) {
        return i + 1;
      }
    }
    return -1;
  }
}

// ============================================
// Retry Status Provider
// ============================================

/// Holds the current retry status
final retryStatusProvider = StreamProvider<RetryStatus>((ref) {
  return RetryService.statusStream;
});

// ============================================
// Selected Files Provider
// ============================================

/// Holds the currently selected files for printing
final selectedFilesProvider = StateNotifierProvider<SelectedFilesNotifier, List<SelectedFile>>(
  (ref) => SelectedFilesNotifier(),
);

class SelectedFilesNotifier extends StateNotifier<List<SelectedFile>> {
  SelectedFilesNotifier() : super([]);

  Future<void> addFile(String name, String path, Uint8List bytes) async {
    // Get page count
    final pageCount = await PdfService.getPageCount(bytes);
    
    final file = SelectedFile(
      name: name,
      path: path,
      sizeBytes: bytes.length,
      pageCount: pageCount,
      bytes: bytes,
    );
    
    state = [...state, file];
  }

  void removeFile(int index) {
    final newState = [...state];
    newState.removeAt(index);
    state = newState;
  }

  void clearFiles() {
    state = [];
  }

  void reorderFiles(int oldIndex, int newIndex) {
    final newState = [...state];
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = newState.removeAt(oldIndex);
    newState.insert(newIndex, item);
    state = newState;
  }

  int get totalPages => state.fold(0, (sum, file) => sum + file.pageCount);
  int get totalSize => state.fold(0, (sum, file) => sum + file.sizeBytes);
}

// ============================================
// Print Config Provider
// ============================================

/// Holds the current print configuration
final printConfigProvider = StateNotifierProvider<PrintConfigNotifier, PrintConfig>(
  (ref) => PrintConfigNotifier(),
);

class PrintConfigNotifier extends StateNotifier<PrintConfig> {
  PrintConfigNotifier() : super(PrintConfig());

  void setPaperSize(String size) {
    state = state.copyWith(paperSize: size);
  }

  void setPrintType(String type) {
    state = state.copyWith(printType: type);
  }

  void setPrintSide(String side) {
    state = state.copyWith(printSide: side);
  }

  void setCopies(int copies) {
    if (copies >= 1 && copies <= 100) {
      state = state.copyWith(copies: copies);
    }
  }

  void setBindingType(String bindingType) {
    state = state.copyWith(bindingType: bindingType);
  }

  void reset() {
    state = PrintConfig();
  }
}

// ============================================
// Student Details Provider
// ============================================

/// Holds the current student details
final studentDetailsProvider = StateNotifierProvider<StudentDetailsNotifier, StudentDetails>(
  (ref) => StudentDetailsNotifier(),
);

class StudentDetailsNotifier extends StateNotifier<StudentDetails> {
  StudentDetailsNotifier() : super(StudentDetails.empty()) {
    _loadSavedDetails();
  }

  void _loadSavedDetails() {
    final saved = StorageService.getSavedStudentDetails();
    if (saved != null) {
      state = saved;
    }
  }

  void updateName(String name) {
    state = StudentDetails(
      name: name,
      studentId: state.studentId,
      phone: state.phone,
      email: state.email,
      additionalInfo: state.additionalInfo,
    );
  }

  void updateStudentId(String id) {
    state = StudentDetails(
      name: state.name,
      studentId: id,
      phone: state.phone,
      email: state.email,
      additionalInfo: state.additionalInfo,
    );
  }

  void updatePhone(String phone) {
    state = StudentDetails(
      name: state.name,
      studentId: state.studentId,
      phone: phone,
      email: state.email,
      additionalInfo: state.additionalInfo,
    );
  }

  void updateEmail(String email) {
    state = StudentDetails(
      name: state.name,
      studentId: state.studentId,
      phone: state.phone,
      email: email,
      additionalInfo: state.additionalInfo,
    );
  }

  void updateAdditionalInfo(String additionalInfo) {
    state = StudentDetails(
      name: state.name,
      studentId: state.studentId,
      phone: state.phone,
      email: state.email,
      additionalInfo: additionalInfo,
    );
  }

  Future<void> saveForLater() async {
    await StorageService.saveStudentDetails(state);
  }

  void clear() {
    state = StudentDetails.empty();
  }
}

// ============================================
// Payment Verification Provider
// ============================================

/// Live OCR Log Provider - shows real-time OCR processing steps
final ocrLogProvider = StateNotifierProvider<OcrLogNotifier, List<String>>(
  (ref) => OcrLogNotifier(),
);

class OcrLogNotifier extends StateNotifier<List<String>> {
  OcrLogNotifier() : super([]);
  
  void addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    state = [...state, '[$timestamp] $message'];
  }
  
  void clear() {
    state = [];
  }
}

/// Holds the payment verification state
final paymentVerificationProvider = StateNotifierProvider<PaymentVerificationNotifier, PaymentVerification?>(
  (ref) => PaymentVerificationNotifier(),
);

class PaymentVerificationNotifier extends StateNotifier<PaymentVerification?> {
  PaymentVerificationNotifier() : super(null);

  /// Store screenshot for sending to Xerox Manager (OCR removed)
  void storeScreenshot(Uint8List imageBytes, double expectedAmount) {
    state = PaymentVerification(
      isVerified: true,  // Always verified - manual check by Xerox
      confidenceScore: 1.0,
      screenshotBytes: imageBytes,
      amount: expectedAmount,
      transactionId: 'MANUAL_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  void setVerification(PaymentVerification verification) {
    state = verification;
  }

  void clear() {
    state = null;
  }
}

// ============================================
// Order Processing Provider
// ============================================

/// Represents the current processing state
class ProcessingState {
  final bool isProcessing;
  final String? currentStep;
  final double progress;
  final String? error;
  final PrintOrder? completedOrder;

  ProcessingState({
    this.isProcessing = false,
    this.currentStep,
    this.progress = 0,
    this.error,
    this.completedOrder,
  });

  ProcessingState copyWith({
    bool? isProcessing,
    String? currentStep,
    double? progress,
    String? error,
    PrintOrder? completedOrder,
  }) {
    return ProcessingState(
      isProcessing: isProcessing ?? this.isProcessing,
      currentStep: currentStep ?? this.currentStep,
      progress: progress ?? this.progress,
      error: error,
      completedOrder: completedOrder ?? this.completedOrder,
    );
  }
}

final orderProcessingProvider = StateNotifierProvider<OrderProcessingNotifier, ProcessingState>(
  (ref) => OrderProcessingNotifier(ref),
);

class OrderProcessingNotifier extends StateNotifier<ProcessingState> {
  final Ref _ref;

  OrderProcessingNotifier(this._ref) : super(ProcessingState());

  Future<PrintOrder?> processOrder({Function(String)? onLog}) async {
    void log(String msg) {
      if (kDebugMode) debugPrint('OrderProcessing: $msg');
      onLog?.call(msg);
    }
    
    state = ProcessingState(isProcessing: true, currentStep: 'Preparing order...', progress: 0.1);

    try {
      log('Starting order processing...');
      final files = _ref.read(selectedFilesProvider);
      final config = _ref.read(printConfigProvider);
      final student = _ref.read(studentDetailsProvider);
      final payment = _ref.read(paymentVerificationProvider);

      log('Files: ${files.length}, Config: ${config.paperSize}');
      log('Student: ${student.name}, ID: ${student.studentId}');
      log('Payment verified: ${payment?.isVerified}, TxnId: ${payment?.transactionId}');
      log('Payment screenshot bytes: ${payment?.screenshotBytes?.length ?? 0} bytes');
      
      // Generate order ID
      final orderId = generateOrderId();
      log('Generated order ID: $orderId');

      state = state.copyWith(currentStep: 'Generating front page...', progress: 0.3);
      log('Step: Generating front page PDF...');

      // Create initial order
      var order = PrintOrder(
        orderId: orderId,
        files: files,
        config: config,
        student: student,
        payment: payment,
        createdAt: DateTime.now(),
        status: 'processing',
      );

      // Generate front page PDF with timeout
      log('Calling PdfService.generateFrontPage...');
      final frontPageBytes = await PdfService.generateFrontPage(order, onLog: onLog).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          log('ERROR: Front page generation TIMEOUT after 30s!');
          throw Exception('Front page generation timed out');
        },
      );
      log('Front page generated: ${frontPageBytes.length} bytes');

      state = state.copyWith(currentStep: 'Merging PDFs...', progress: 0.5);
      log('Step: Merging PDFs...');

      // Merge front page with document PDFs
      final documentBytesList = files
          .where((f) => f.bytes != null)
          .map((f) => f.bytes!)
          .toList();
      
      log('Documents to merge: ${documentBytesList.length}');
      for (int i = 0; i < documentBytesList.length; i++) {
        log('  Doc $i: ${documentBytesList[i].length} bytes');
      }

      // Duplicate documents in mobile app per user request
      log('Duplicating documents ${config.copies} times...');
      final List<Uint8List> duplicatedDocuments = [];
      for (int c = 0; c < config.copies; c++) {
        duplicatedDocuments.addAll(documentBytesList);
      }

      final mergedPdfBytes = await PdfService.mergeWithFrontPage(
        frontPageBytes,
        duplicatedDocuments,
        onLog: onLog,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          log('ERROR: PDF merge TIMEOUT after 60s!');
          throw Exception('PDF merge timed out');
        },
      );
      log('PDFs merged successfully: ${mergedPdfBytes.length} bytes');

      order = order.copyWith(mergedPdfBytes: mergedPdfBytes);

      state = state.copyWith(currentStep: 'Uploading to server...', progress: 0.7);
      log('Step: Uploading to server...');

      // Try to upload
      final result = await ApiService.uploadOrder(order);
      log('Upload result: success=${result.success}, message=${result.message}');

      if (result.success) {
        log('Order submitted successfully!');
        state = state.copyWith(
          currentStep: 'Order submitted!',
          progress: 1.0,
          completedOrder: order.copyWith(status: 'completed'),
        );
        
        // Clear form state using delayed future to ensure we're out of any build cycle
        Future.delayed(Duration.zero, () async {
          _ref.read(selectedFilesProvider.notifier).clearFiles();
          _ref.read(printConfigProvider.notifier).reset();
          _ref.read(paymentVerificationProvider.notifier).clear();
          
          // Cleanup all files from PrintApp Gallery album
          try {
             final dir = Directory('/storage/emulated/0/Pictures/PrintApp');
             if (await dir.exists()) {
                for (var entity in dir.listSync()) {
                   if (entity is File) {
                      await entity.delete();
                   }
                }
             }
          } catch(e) {
             if (kDebugMode) debugPrint('Could not delete files: $e');
          }
        });
        
        return order.copyWith(status: 'completed');
      } else {
        // Queue for retry
        log('Upload failed, queuing for retry...');
        state = state.copyWith(currentStep: 'Queuing for retry...', progress: 0.9);
        
        final queuedOrder = order.copyWith(
          status: 'queued',
          errorMessage: result.message,
        );
        
        // Save to storage immediately (storage operation is safe)
        await StorageService.addPendingOrder(queuedOrder);
        
        state = state.copyWith(
          isProcessing: false,
          currentStep: 'Order queued',
          progress: 1.0,
          completedOrder: queuedOrder,
        );
        
        // Use Future.delayed to ensure we're in a new event loop iteration
        // This prevents "modify provider during build" errors
        Future.delayed(Duration.zero, () async {
          // Refresh pending orders list (use sync since we're already in delayed callback)
          _ref.read(pendingOrdersProvider.notifier).refreshSync();
          // Clear form state
          _ref.read(selectedFilesProvider.notifier).clearFiles();
          _ref.read(printConfigProvider.notifier).reset();
          _ref.read(paymentVerificationProvider.notifier).clear();
          
          // Cleanup all files from PrintApp Gallery album
          try {
             final dir = Directory('/storage/emulated/0/Pictures/PrintApp');
             if (await dir.exists()) {
                for (var entity in dir.listSync()) {
                   if (entity is File) {
                      await entity.delete();
                   }
                }
             }
          } catch(e) {
             if (kDebugMode) debugPrint('Could not delete files: $e');
          }
        });
        
        return queuedOrder;
      }
    } catch (e) {
      state = ProcessingState(
        isProcessing: false,
        error: e.toString(),
      );
      return null;
    }
  }

  void reset() {
    state = ProcessingState();
  }
}

// ============================================
// Theme Provider
// ============================================

/// Holds the current theme mode
final themeProvider = StateNotifierProvider<ThemeNotifier, bool>(
  (ref) => ThemeNotifier(),
);

class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier() : super(StorageService.isDarkMode);

  Future<void> toggle() async {
    state = !state;
    await StorageService.setDarkMode(state);
  }

  Future<void> setDarkMode(bool value) async {
    state = value;
    await StorageService.setDarkMode(value);
  }
}

// ============================================
// Computed Providers
// ============================================

/// Total price based on selected files and config
final totalPriceProvider = Provider<double>((ref) {
  final files = ref.watch(selectedFilesProvider);
  final config = ref.watch(printConfigProvider);
  final totalPages = files.fold(0, (sum, file) => sum + file.pageCount);
  return config.calculateTotalPrice(totalPages);
});

/// Check if order can proceed
final canProceedToPaymentProvider = Provider<bool>((ref) {
  final files = ref.watch(selectedFilesProvider);
  final student = ref.watch(studentDetailsProvider);
  return files.isNotEmpty && student.isValid;
});

/// Count of pending orders
final pendingOrderCountProvider = Provider<int>((ref) {
  final orders = ref.watch(pendingOrdersProvider);
  return orders.length;
});
