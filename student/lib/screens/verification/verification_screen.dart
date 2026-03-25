import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:typed_data';
import '../../config/theme.dart';
import '../../models/print_order.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/helpers.dart';
import '../processing/processing_screen.dart';

/// Simplified Verification Screen - No OCR
/// Just shows screenshot preview and allows user to confirm & proceed
class VerificationScreen extends ConsumerStatefulWidget {
  final Uint8List screenshotBytes;

  const VerificationScreen({
    super.key,
    required this.screenshotBytes,
  });

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  
  @override
  void initState() {
    super.initState();
    // Store the screenshot bytes in the payment verification provider
    _storeScreenshot();
  }

  void _storeScreenshot() {
    // Create a simple payment verification with just the screenshot
    final verification = PaymentVerification(
      isVerified: true, // Always verified since we're skipping OCR
      confidenceScore: 1.0, // Full confidence
      screenshotBytes: widget.screenshotBytes,
      transactionId: 'MANUAL_UPLOAD_${DateTime.now().millisecondsSinceEpoch}',
      amount: ref.read(totalPriceProvider),
    );
    
    ref.read(paymentVerificationProvider.notifier).setVerification(verification);
  }

  void _proceed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProcessingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = ref.watch(totalPriceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Payment'),
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: const ProgressStepper(
              currentStep: 4,
              steps: ['Files', 'Config', 'Details', 'Payment', 'Done'],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  GlassCard(
                    gradient: AppTheme.accentGradient,
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Screenshot',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Your screenshot will be sent to the print shop for verification',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: -0.1, end: 0),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Amount Display
                  GlassCard(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment Amount',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          formatCurrency(totalPrice),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Screenshot Preview
                  const SectionHeader(
                    title: 'Screenshot Preview',
                    subtitle: 'Please verify this is your payment screenshot',
                  ),
                  
                  const SizedBox(height: AppTheme.spacingSM),

                  GlassCard(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      child: Image.memory(
                        widget.screenshotBytes,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Note
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      border: Border.all(
                        color: AppTheme.warningColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.warningColor,
                          size: 24,
                        ),
                        const SizedBox(width: AppTheme.spacingSM),
                        const Expanded(
                          child: Text(
                            'The print shop will verify your payment manually. Please ensure the screenshot clearly shows the transaction.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                ],
              ),
            ),
          ),

          // Bottom Bar
          _buildBottomBar(context),
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
                text: 'Confirm & Submit Order',
                onPressed: _proceed,
                icon: Icons.check_circle,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Choose Different Screenshot'),
            ),
          ],
        ),
      ),
    );
  }
}
