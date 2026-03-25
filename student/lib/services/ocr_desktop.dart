import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Desktop OCR implementation using Tesseract
class OcrDesktop {
  static bool _isInitialized = false;
  
  /// Initialize Tesseract with trained data
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Tesseract will use system-installed tessdata or bundled data
      _isInitialized = true;
      if (kDebugMode) debugPrint('Tesseract OCR initialized for desktop');
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing Tesseract: $e');
    }
  }
  
  /// Perform OCR on image bytes
  static Future<String> performOcr(Uint8List imageBytes) async {
    try {
      await initialize();
      
      // Save image to temp file for Tesseract processing
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(imageBytes);
      
      // Perform OCR
      final result = await FlutterTesseractOcr.extractText(
        tempFile.path,
        language: 'eng',
        args: {
          "psm": "3", // Fully automatic page segmentation
          "preserve_interword_spaces": "1",
        },
      );
      
      // Cleanup temp file
      try {
        await tempFile.delete();
      } catch (_) {}
      
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('Error performing desktop OCR: $e');
      return '';
    }
  }
  
  /// Dispose resources
  static void dispose() {
    _isInitialized = false;
  }
}
