import 'dart:io';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

/// Print Service for handling print operations
class PrintService {
  /// Get list of available printers
  static Future<List<Printer>> getAvailablePrinters() async {
    try {
      final printers = await Printing.listPrinters();
      return printers;
    } catch (e) {
      print('Error getting printers: $e');
      return [];
    }
  }

  /// Print PDF file
  static Future<bool> printPdf({
    required String filePath,
    String? printerName,
    bool showDialog = true,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      final bytes = await file.readAsBytes();

      if (showDialog) {
        // Show system print dialog
        final result = await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => bytes,
          name: file.path.split(Platform.pathSeparator).last,
        );
        return result;
      } else if (printerName != null) {
        // Direct print to specified printer
        final printers = await Printing.listPrinters();
        final printer = printers.firstWhere(
          (p) => p.name == printerName,
          orElse: () => throw Exception('Printer not found: $printerName'),
        );

        final result = await Printing.directPrintPdf(
          printer: printer,
          onLayout: (PdfPageFormat format) async => bytes,
          name: file.path.split(Platform.pathSeparator).last,
        );
        return result;
      }

      return false;
    } catch (e) {
      print('Print error: $e');
      return false;
    }
  }

  /// Check if printing is available
  static Future<bool> isPrintingAvailable() async {
    try {
      return await Printing.info().then((info) => info.canPrint);
    } catch (e) {
      return false;
    }
  }

  /// Get default printer name
  static Future<String?> getDefaultPrinter() async {
    try {
      final printers = await Printing.listPrinters();
      final defaultPrinter = printers.firstWhere(
        (p) => p.isDefault,
        orElse: () => printers.isNotEmpty ? printers.first : Printer(url: ''),
      );
      return defaultPrinter.name;
    } catch (e) {
      return null;
    }
  }
}
