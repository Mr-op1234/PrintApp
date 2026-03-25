import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Mobile-specific OCR implementation using Google ML Kit
class OcrMobile {
  static TextRecognizer? _textRecognizer;
  
  /// Get or create text recognizer instance
  static TextRecognizer get textRecognizer {
    _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _textRecognizer!;
  }
  
  /// Perform OCR on image bytes (without logging)
  static Future<String> performOcr(Uint8List imageBytes) async {
    return performOcrWithLog(imageBytes, onLog: null);
  }
  
  /// Perform OCR on image bytes with live logging
  static Future<String> performOcrWithLog(Uint8List imageBytes, {Function(String)? onLog}) async {
    void log(String msg) {
      if (kDebugMode) debugPrint('OcrMobile: $msg');
      onLog?.call('ML Kit: $msg');
    }
    
    log('Starting OCR...');
    log('Image bytes: ${imageBytes.length}');
    File? tempFile;
    
    try {
      // Save image to temporary file (ML Kit requires file path)
      log('Getting temp directory...');
      final tempDir = await getTemporaryDirectory();
      log('Temp dir: ${tempDir.path}');
      
      final fileName = 'ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg';
      tempFile = File('${tempDir.path}/$fileName');
      
      log('Writing image to file...');
      await tempFile.writeAsBytes(imageBytes);
      log('File written: ${tempFile.path}');
      
      // Verify file exists
      if (!await tempFile.exists()) {
        log('ERROR: Temp file does not exist!');
        return '';
      }
      log('File size: ${await tempFile.length()} bytes');
      
      // Create input image
      log('Creating InputImage from file...');
      final inputImage = InputImage.fromFilePath(tempFile.path);
      log('InputImage created');
      
      // Perform recognition with timeout
      log('Calling ML Kit processImage...');
      final stopwatch = Stopwatch()..start();
      
      final recognizedText = await textRecognizer.processImage(inputImage)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              log('ERROR: ML Kit timed out after 30 seconds!');
              throw Exception('OCR timed out');
            },
          );
      
      stopwatch.stop();
      log('ML Kit completed in ${stopwatch.elapsedMilliseconds}ms');
      log('Extracted ${recognizedText.text.length} characters');
      log('Found ${recognizedText.blocks.length} text blocks');
      
      return recognizedText.text;
    } catch (e, stackTrace) {
      log('ERROR: $e');
      log('Stack: ${stackTrace.toString().split('\n').take(2).join(' | ')}');
      return '';
    } finally {
      // Clean up temp file
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
            log('Temp file deleted');
          }
        } catch (e) {
          log('Warning: Could not delete temp file: $e');
        }
      }
    }
  }
  
  /// Dispose resources
  static Future<void> dispose() async {
    await _textRecognizer?.close();
    _textRecognizer = null;
  }
}
