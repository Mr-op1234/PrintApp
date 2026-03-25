import 'dart:typed_data';

/// Stub OCR implementation for web platform where local OCR is not available
class OcrMobile {
  static Future<String> performOcr(Uint8List imageBytes) async {
    // Not supported on web - return empty string
    return '';
  }
  
  static Future<void> dispose() async {}
}

class OcrDesktop {
  static Future<String> performOcr(Uint8List imageBytes) async {
    // Not supported on web - return empty string
    return '';
  }
  
  static void dispose() {}
}
