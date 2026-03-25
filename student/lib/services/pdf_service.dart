import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import '../models/print_order.dart';
import '../utils/helpers.dart';
import '../utils/platform_utils.dart';

/// Service for PDF operations (page count, merging, front page generation)
class PdfService {
  /// Get page count from PDF bytes
  static Future<int> getPageCount(Uint8List pdfBytes) async {
    try {
      final document = syncfusion.PdfDocument(inputBytes: pdfBytes);
      final pageCount = document.pages.count;
      document.dispose();
      return pageCount;
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting page count: $e');
      return 0;
    }
  }

  /// Validate if the bytes represent a valid PDF
  static bool isValidPdf(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // Check PDF magic number
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46; // F
  }

  /// Generate front page PDF with order details and QR code
  /// Uses B&W design and matches document page configuration
  static Future<Uint8List> generateFrontPage(PrintOrder order, {Function(String)? onLog}) async {
    void log(String msg) {
      if (kDebugMode) debugPrint('PdfService: $msg');
      onLog?.call('PDF: $msg');
    }
    
    log('Starting front page generation for order ${order.orderId}');
    final pdf = pw.Document();
    
    // SKIP QR code generation - it hangs on Android
    // Just use text-based order ID display instead
    log('Skipping QR code (causes hang), using text display');
    final pw.ImageProvider? qrImage = null;
    
    log('Determining page format...');
    // Determine page format based on document config
    PdfPageFormat pageFormat;
    switch (order.config.paperSize.toUpperCase()) {
      case 'LETTER':
        pageFormat = PdfPageFormat.letter;
        break;
      case 'LEGAL':
        pageFormat = PdfPageFormat.legal;
        break;
      case 'A4':
      default:
        pageFormat = PdfPageFormat.a4;
        break;
    }
    
    log('Adding page to PDF document...');
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header - Simple text only (ink-saving)
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PRINT ORDER',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'College Xerox Shop',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 30),
              
              // Order ID and QR Code
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Order ID',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        order.orderId,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 16),
                      pw.Text(
                        'Date & Time',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        formatDate(order.createdAt),
                        style: pw.TextStyle(fontSize: 14, color: PdfColors.black),
                      ),
                    ],
                  ),
                  if (qrImage != null)
                    pw.Container(
                      width: 100,
                      height: 100,
                      child: pw.Image(qrImage),
                    ),
              ],
              ),
              
              pw.SizedBox(height: 30),
              
              // Divider
              pw.Divider(color: PdfColors.grey400),
              
              pw.SizedBox(height: 20),
              
              // Student Details Section (No email)
              _buildSectionBW('Student Details', [
                _buildDetailRowBW('Name', order.student.name),
                _buildDetailRowBW('Enrollment No.', order.student.studentId),
                _buildDetailRowBW('Phone', order.student.phone),
              ]),
              
              pw.SizedBox(height: 24),
              
              // Print Configuration Section
              _buildSectionBW('Print Configuration', [
                _buildDetailRowBW('Paper Size', order.config.paperSize),
                _buildDetailRowBW('Print Type', order.config.printType == 'BW' ? 'Black & White' : 'Color'),
                _buildDetailRowBW('Sides', order.config.printSide == 'SINGLE' ? 'Single Sided' : 'Double Sided'),
                _buildDetailRowBW('Copies', order.config.copies.toString()),
              ]),
              
              pw.SizedBox(height: 24),
              
              // Documents Section
              _buildSectionBW('Documents', [
                for (final file in order.files)
                  _buildDetailRowBW(file.name, '${file.pageCount} pages'),
              ]),
              
              pw.SizedBox(height: 30),
              
              // Summary Box - B&W
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey500),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Total Pages: ${order.totalPages}',
                          style: pw.TextStyle(fontSize: 14, color: PdfColors.black),
                        ),
                        pw.Text(
                          'Files: ${order.files.length}',
                          style: pw.TextStyle(fontSize: 14, color: PdfColors.black),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Total Amount',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          formatCurrency(order.totalPrice),
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              pw.Spacer(),
              
              // Footer - B&W
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey400),
                  ),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Payment ${order.payment?.isVerified == true ? 'VERIFIED' : 'PENDING'}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    if (order.payment?.transactionId != null)
                      pw.Text(
                        'Transaction ID: ${order.payment!.transactionId}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Generated on ${PlatformUtils.platformName}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    
    log('Page added. Saving PDF document...');
    final bytes = await pdf.save();
    log('Front page PDF saved successfully: ${bytes.length} bytes');
    return bytes;
  }

  /// Helper to build section widget (B&W version)
  static pw.Widget _buildSectionBW(String title, List<pw.Widget> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 12),
        ...rows,
      ],
    );
  }

  /// Helper to build detail row (B&W version)
  static pw.Widget _buildDetailRowBW(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper to build section widget
  static pw.Widget _buildSection(String title, List<pw.Widget> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        ...rows,
      ],
    );
  }

  /// Helper to build detail row
  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Generate QR code image for PDF
  static Future<pw.ImageProvider?> _generateQrImage(String data) async {
    try {
      if (kDebugMode) debugPrint('PdfService: Creating QR painter...');
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );
      
      if (kDebugMode) debugPrint('PdfService: Converting QR to image...');
      final image = await qrPainter.toImage(200).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) debugPrint('PdfService: QR toImage TIMEOUT!');
          throw Exception('QR code generation timed out');
        },
      );
      
      if (kDebugMode) debugPrint('PdfService: Getting byte data from QR image...');
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          if (kDebugMode) debugPrint('PdfService: toByteData TIMEOUT!');
          return null;
        },
      );
      if (byteData == null) {
        if (kDebugMode) debugPrint('PdfService: QR byteData is null');
        return null;
      }
      
      if (kDebugMode) debugPrint('PdfService: QR image generated successfully (${byteData.lengthInBytes} bytes)');
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (e) {
      if (kDebugMode) debugPrint('Error generating QR image: $e');
      return null;
    }
  }

  /// Merge multiple PDFs into one while preserving original page sizes
  static Future<Uint8List> mergePdfs(List<Uint8List> pdfBytesList, {Function(String)? onLog}) async {
    void log(String msg) {
      if (kDebugMode) debugPrint('PdfService: $msg');
      onLog?.call('PDF: $msg');
    }
    
    log('Starting PDF merge of ${pdfBytesList.length} documents');
    final mergedDocument = syncfusion.PdfDocument();
    int docIndex = 0;
    
    for (final pdfBytes in pdfBytesList) {
      log('Processing document $docIndex (${pdfBytes.length} bytes)...');
      docIndex++;
      try {
        log('  Loading document...');
        final document = syncfusion.PdfDocument(inputBytes: pdfBytes);
        log('  Document has ${document.pages.count} pages');
        
        for (int i = 0; i < document.pages.count; i++) {
          log('  Processing page ${i + 1}/${document.pages.count}...');
          final sourcePage = document.pages[i];
          final template = sourcePage.createTemplate();
          
          // Add a new section for this page to control its size independent of others
          final section = mergedDocument.sections!.add();
          
          // Set the page size to match source (use size, not clientSize to include margins)
          section.pageSettings.size = sourcePage.size;
          section.pageSettings.margins.all = 0;
          
          // Add page to this section
          final page = section.pages.add();
          
          // Draw the template
          page.graphics.drawPdfTemplate(
            template,
            ui.Offset.zero,
            sourcePage.size,
          );
        }
        document.dispose();
        log('  Document $docIndex processed successfully');
      } catch (e) {
        log('ERROR merging PDF document $docIndex: $e');
      }
    }
    
    log('Saving merged PDF...');
    final mergedBytes = Uint8List.fromList(mergedDocument.saveSync());
    mergedDocument.dispose();
    log('Merged PDF saved: ${mergedBytes.length} bytes');
    
    return mergedBytes;
  }

  /// Merge front page with document PDFs
  static Future<Uint8List> mergeWithFrontPage(
    Uint8List frontPageBytes, 
    List<Uint8List> documentBytesList,
    {Function(String)? onLog}
  ) async {
    onLog?.call('PDF: Merging front page with ${documentBytesList.length} documents...');
    return mergePdfs([frontPageBytes, ...documentBytesList], onLog: onLog);
  }
}
