import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart';
import '../config/app_config.dart';

/// File Service for PDF storage and management
class FileService {
  /// Save PDF bytes to local directory
  static Future<String> savePdf({
    required Uint8List pdfBytes,
    required String orderId,
    required String studentName,
    required String saveDirectory,
  }) async {
    // Ensure directory exists
    final dir = Directory(saveDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Generate filename
    final filename = AppConfig.generateFilename(orderId, studentName, DateTime.now());
    final filePath = path.join(saveDirectory, filename);

    // Write file
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    print('PDF saved: $filePath');
    return filePath;
  }

  /// Open PDF in default viewer
  static Future<void> openPdf(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await OpenFile.open(filePath);
    } else {
      throw Exception('File not found: $filePath');
    }
  }

  /// Delete PDF file
  static Future<void> deletePdf(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      print('PDF deleted: $filePath');
    }
  }

  /// Check if PDF file exists
  static Future<bool> pdfExists(String filePath) async {
    return await File(filePath).exists();
  }

  /// Get file size
  static Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Check available disk space
  static Future<int> getAvailableDiskSpace(String directoryPath) async {
    try {
      if (Platform.isWindows) {
        // Windows: Use WMIC command
        final result = await Process.run('wmic', [
          'logicaldisk',
          'where',
          'DeviceID="${directoryPath.substring(0, 2)}"',
          'get',
          'FreeSpace',
          '/value'
        ]);
        final output = result.stdout.toString();
        final match = RegExp(r'FreeSpace=(\d+)').firstMatch(output);
        if (match != null) {
          return int.parse(match.group(1)!);
        }
      } else if (Platform.isMacOS || Platform.isLinux) {
        // Unix: Use df command
        final result = await Process.run('df', ['-B1', directoryPath]);
        final lines = result.stdout.toString().split('\n');
        if (lines.length > 1) {
          final parts = lines[1].split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            return int.parse(parts[3]);
          }
        }
      }
    } catch (e) {
      print('Error checking disk space: $e');
    }
    return -1; // Unknown
  }

  /// Check if disk space is low
  static Future<bool> isDiskSpaceLow(String directoryPath) async {
    final available = await getAvailableDiskSpace(directoryPath);
    if (available < 0) return false; // Couldn't determine
    return available < AppConfig.diskSpaceWarningBytes;
  }

  /// Validate PDF bytes
  static bool isValidPdf(Uint8List bytes) {
    if (bytes.length < 5) return false;
    // Check PDF magic number: %PDF-
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46 && // F
        bytes[4] == 0x2D; // -
  }

  /// Get list of PDF files in directory
  static Future<List<FileSystemEntity>> listPdfFiles(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return [];

    return await dir
        .list()
        .where((entity) => entity.path.toLowerCase().endsWith('.pdf'))
        .toList();
  }
}
