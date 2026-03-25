import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
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

  String get _upiUri {
    final totalPrice = ref.read(totalPriceProvider);
    final orderId = 'PO${DateTime.now().millisecondsSinceEpoch}';
    return 'upi://pay?pa=${AppConfig.upiId}&pn=${Uri.encodeComponent(AppConfig.upiMerchantName)}&am=${totalPrice.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent("Print Order $orderId")}';
  }

  Future<void> _launchUpiApp(String packageName) async {
    setState(() {
      _selectedApp = packageName;
      _isLoading = true;
    });

    try {
      final uri = Uri.parse(_upiUri);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch UPI app'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
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

                  // UPI Apps Section
                  _buildUpiAppsSection(),

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
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: QrImageView(
              data: _upiUri,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              errorStateBuilder: (context, error) => const Center(
                child: Text('Error generating QR code'),
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

  Widget _buildUpiAppsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pay with App',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: AppTheme.spacingMD),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _launchUpiApp('UPI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text(
              'Open UPI App',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
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
          _buildInstructionStep(1, 'Scan QR code or tap a UPI app above'),
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
        child: SizedBox(
          width: double.infinity,
          child: GradientButton(
            text: 'Upload Payment Screenshot',
            icon: Icons.upload,
            isLoading: _isLoading,
            onPressed: _captureScreenshot,
            gradient: AppTheme.accentGradient,
          ),
        ),
      ),
    );
  }
}
