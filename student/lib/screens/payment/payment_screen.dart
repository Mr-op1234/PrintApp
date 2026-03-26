import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/helpers.dart';
import '../verification/verification_screen.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isLoading = false;
  String? _selectedApp;

  String get _qrUpiUri {
    final totalPrice = ref.read(totalPriceProvider);
    final orderId = 'PO${DateTime.now().millisecondsSinceEpoch}';
    return 'upi://pay?pa=${AppConfig.upiId}&pn=${Uri.encodeComponent(AppConfig.upiMerchantName)}&am=${totalPrice.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent("Print Order $orderId")}';
  }

  Future<void> _saveQrAndOpenUpi() async {
    setState(() => _isLoading = true);
    
    try {
      final qrPainter = QrPainter(
        data: _qrUpiUri,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: false,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
      );
      
      // Generate QR code Image
      final ui.Image qrImage = await qrPainter.toImage(400);
      
      // Create a larger white canvas to place the QR code with borders
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      const double canvasSize = 600.0;
      const double qrSize = 400.0;
      
      // Draw white background
      final paint = ui.Paint()..color = Colors.white;
      canvas.drawRect(const ui.Rect.fromLTWH(0, 0, canvasSize, canvasSize), paint);
      
      // Center the QR image on the canvas
      final offset = (canvasSize - qrSize) / 2.0;
      canvas.drawImage(qrImage, ui.Offset(offset, offset), ui.Paint());
      
      final picture = recorder.endRecording();
      final ui.Image finalImage = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
      final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        
        bool hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) {
          hasAccess = await Gal.requestAccess(toAlbum: true);
        }
        
        if (hasAccess) {
          await Gal.putImageBytes(
            pngBytes, 
            album: 'PrintApp',
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('QR Code saved to gallery!'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
      
      final uri = Uri.parse("upi://pay");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No generic UPI app handler found.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving QR Code: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _captureScreenshot() async {
    setState(() => _isLoading = true);

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VerificationScreen(screenshotBytes: bytes),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing screenshot: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateOfflinePayment() async {
    setState(() => _isLoading = true);
    
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final size = const ui.Size(800, 600);
      
      // Draw white background
      final paint = ui.Paint()..color = Colors.white;
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.width, size.height), paint);
      
      // Draw text
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Payment to be done Offline',
          style: TextStyle(
            color: Colors.black,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: size.width);
      textPainter.paint(
        canvas,
        ui.Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationScreen(screenshotBytes: bytes),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating offline payment: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyUpiId() {
    Clipboard.setData(ClipboardData(text: AppConfig.upiId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('UPI ID copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = ref.watch(totalPriceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: const ProgressStepper(
              currentStep: 3,
              steps: ['Files', 'Config', 'Details', 'Payment', 'Done'],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                children: [
                  // Amount Card
                  _buildAmountCard(totalPrice),

                  const SizedBox(height: AppTheme.spacingLG),

                  // QR Code Card
                  _buildQrCodeCard(),

                  const SizedBox(height: AppTheme.spacingLG),

                  // UPI ID Card
                  _buildUpiIdCard(),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Instructions
                  _buildInstructions(),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildAmountCard(double amount) {
    return GlassCard(
      gradient: AppTheme.successGradient,
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        children: [
          const Text(
            'Total Amount',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatCurrency(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ).animate()
              .fadeIn()
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  Widget _buildQrCodeCard() {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        children: [
          const Text(
            'Scan QR Code to Pay',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          InkWell(
            onTap: _saveQrAndOpenUpi,
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: QrImageView(
                data: _qrUpiUri,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                errorStateBuilder: (context, error) => const Center(
                  child: Text('Error generating QR code'),
                ),
              ),
            ),
          ).animate()
              .fadeIn(delay: 200.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
          const SizedBox(height: AppTheme.spacingSM),
          const Text(
            'Open any UPI app and scan this code',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textMutedDark,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildUpiIdCard() {
    return GlassCard(
      onTap: _copyUpiId,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_balance,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UPI ID',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppConfig.upiId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.copy,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }


  Widget _buildInstructions() {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: AppTheme.infoColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Payment Instructions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _buildInstructionStep(1, 'Tap the QR code to save to gallery and open UPI'),
          _buildInstructionStep(2, 'Complete the payment in your UPI app'),
          _buildInstructionStep(3, 'Take a screenshot of the payment confirmation'),
          _buildInstructionStep(4, 'Tap "Upload Screenshot" below to verify'),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildInstructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(
          top: BorderSide(color: AppTheme.surfaceBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: 'Upload Payment Screenshot',
                icon: Icons.upload,
                isLoading: _isLoading,
                onPressed: _captureScreenshot,
                gradient: AppTheme.accentGradient,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _generateOfflinePayment,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                ),
                icon: const Icon(Icons.money_off, color: AppTheme.primaryColor),
                label: const Text(
                  'Pay Offline (Cash)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
