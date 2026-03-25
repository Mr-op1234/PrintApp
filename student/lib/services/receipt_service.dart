import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Service to generate PDF receipts for successful order submissions
class ReceiptService {
  /// Generate a PDF receipt for a completed order
  static Future<Uint8List> generateReceipt({
    required String orderId,
    required String studentName,
    required String studentId,
    required String phone,
    required double amount,
    required String transactionId,
    required int totalPages,
    required String paperSize,
    required String printType,
    required String printSide,
    required int copies,
    required DateTime submittedAt,
  }) async {
    final pdf = pw.Document();
    
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.deepPurple,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PAYMENT RECEIPT',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Print Order Confirmation',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 24),
              
              // Order Details
              _buildSection('Order Details', [
                _buildRow('Order ID', orderId),
                _buildRow('Date', dateFormat.format(submittedAt)),
                _buildRow('Status', 'CONFIRMED'),
              ]),
              
              pw.SizedBox(height: 16),
              
              // Student Details
              _buildSection('Student Details', [
                _buildRow('Name', studentName),
                _buildRow('Enrollment No.', studentId),
                _buildRow('Phone', phone),
              ]),
              
              pw.SizedBox(height: 16),
              
              // Print Configuration
              _buildSection('Print Configuration', [
                _buildRow('Total Pages', '$totalPages'),
                _buildRow('Paper Size', paperSize),
                _buildRow('Print Type', printType == 'COLOR' ? 'Color' : 'Black & White'),
                _buildRow('Print Side', printSide == 'DOUBLE' ? 'Double-sided' : 'Single-sided'),
                _buildRow('Copies', '$copies'),
              ]),
              
              pw.SizedBox(height: 16),
              
              // Payment Details
              _buildSection('Payment Details', [
                _buildRow('Transaction ID', transactionId),
                _buildRow('Payment Method', 'UPI'),
                _buildRow('Paid To', 'ABDUL MANNAN MOLLA'),
                _buildRow('UPI ID', 'q014782270@ybl'),
              ]),
              
              pw.SizedBox(height: 16),
              
              // Amount
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.green),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Amount Paid',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '₹${amount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.Spacer(),
              
              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your order!',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Please show this receipt at the print shop',
                      style: const pw.TextStyle(
                        fontSize: 10,
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
    
    return pdf.save();
  }
  
  static pw.Widget _buildSection(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.deepPurple,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(children: children),
        ),
      ],
    );
  }
  
  static pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  /// Save receipt to downloads folder and return file path
  static Future<String> saveReceipt(Uint8List pdfBytes, String orderId) async {
    final dir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${dir.path}/PrintApp/Receipts');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    
    final filePath = '${receiptsDir.path}/Receipt_$orderId.pdf';
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    
    return filePath;
  }
  
  /// Get all saved receipts
  static Future<List<File>> getSavedReceipts() async {
    final dir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${dir.path}/PrintApp/Receipts');
    
    if (!await receiptsDir.exists()) {
      return [];
    }
    
    return receiptsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.pdf'))
        .toList();
  }
}
