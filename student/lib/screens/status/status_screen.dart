import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/receipt_service.dart';
import '../../config/theme.dart';
import '../../models/print_order.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/helpers.dart';
import '../home/home_screen.dart';
import '../pending_orders/pending_orders_screen.dart';

class StatusScreen extends ConsumerWidget {
  final PrintOrder order;

  const StatusScreen({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = order.status == 'completed';
    final isQueued = order.status == 'queued';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                automaticallyImplyLeading: false,
                title: const Text('Order Status'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () => _shareOrderDetails(context),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Status Hero
                    _buildStatusHero(context, isCompleted, isQueued),

                    const SizedBox(height: AppTheme.spacingLG),

                    // Order QR Code
                    _buildOrderQrCard(),

                    const SizedBox(height: AppTheme.spacingLG),

                    // Order Details
                    _buildOrderDetailsCard(context),

                    const SizedBox(height: AppTheme.spacingLG),

                    // Files Summary
                    _buildFilesSummary(context),

                    const SizedBox(height: AppTheme.spacingLG),

                    // Print Configuration
                    _buildConfigCard(context),

                    const SizedBox(height: AppTheme.spacingLG),

                    // Payment Info
                    if (order.payment != null) _buildPaymentCard(context),

                    const SizedBox(height: AppTheme.spacingLG),

                    // Queue Info (if queued)
                    if (isQueued) _buildQueueInfoCard(context),

                    const SizedBox(height: AppTheme.spacingXL),

                    // Action Buttons
                    _buildActionButtons(context, isQueued),

                    const SizedBox(height: AppTheme.spacingMD),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHero(BuildContext context, bool isCompleted, bool isQueued) {
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    if (isCompleted) {
      statusColor = AppTheme.successColor;
      statusIcon = Icons.check_circle;
      statusTitle = 'Order Submitted!';
      statusSubtitle = 'Your print order has been sent to the xerox shop';
    } else if (isQueued) {
      statusColor = AppTheme.warningColor;
      statusIcon = Icons.schedule;
      statusTitle = 'Order Queued';
      statusSubtitle = 'Will be uploaded when server is available';
    } else {
      statusColor = AppTheme.infoColor;
      statusIcon = Icons.hourglass_empty;
      statusTitle = 'Processing';
      statusSubtitle = 'Your order is being processed';
    }

    return GlassCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          statusColor.withOpacity(0.2),
          statusColor.withOpacity(0.05),
        ],
      ),
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              size: 40,
              color: statusColor,
            ),
          ).animate()
              .scale(duration: 500.ms, curve: Curves.elasticOut)
              .then()
              .shake(hz: 2, offset: const Offset(2, 0)),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          Text(
            statusTitle,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ).animate().fadeIn(delay: 200.ms),
          
          const SizedBox(height: 8),
          
          Text(
            statusSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMutedDark),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  Widget _buildOrderQrCard() {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(
              data: order.orderId,
              version: QrVersions.auto,
              size: 80,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order ID',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.orderId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Show this QR at the xerox shop',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildOrderDetailsCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Order Details'),
          _buildDetailRow(Icons.person, 'Name', order.student.name),
          _buildDetailRow(Icons.badge, 'Enrollment No.', order.student.studentId),
          _buildDetailRow(Icons.phone, 'Phone', order.student.phone),
          _buildDetailRow(Icons.email, 'Email', order.student.email),
          _buildDetailRow(Icons.calendar_today, 'Date', formatDate(order.createdAt)),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMutedDark,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesSummary(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Documents'),
          ...order.files.map((file) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    file.name,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${file.pageCount} pages',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
              ],
            ),
          )),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryChip(Icons.insert_drive_file, '${order.files.length} files'),
              _buildSummaryChip(Icons.layers, '${order.totalPages} pages'),
              _buildSummaryChip(Icons.storage, order.formattedTotalSize),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildSummaryChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Print Configuration'),
          Row(
            children: [
              Expanded(child: _buildConfigItem('Paper', order.config.paperSize)),
              Expanded(child: _buildConfigItem('Type', order.config.printType == 'BW' ? 'B&W' : 'Color')),
              Expanded(child: _buildConfigItem('Sides', order.config.printSide == 'SINGLE' ? 'Single' : 'Double')),
              Expanded(child: _buildConfigItem('Copies', '${order.config.copies}')),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildConfigItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textMutedDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: order.payment!.isVerified
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  order.payment!.isVerified ? 'Verified' : 'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: order.payment!.isVerified
                        ? AppTheme.successColor
                        : AppTheme.warningColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount'),
              Text(
                formatCurrency(order.totalPrice),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),
          if (order.payment!.transactionId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Transaction: ${order.payment!.transactionId}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMutedDark,
                fontFamily: 'monospace',
              ),
            ),
          ],
          
          if (order.payment!.isVerified) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generating receipt...')),
                    );
                    
                    final pdfBytes = await ReceiptService.generateReceipt(
                      orderId: order.orderId,
                      studentName: order.student.name,
                      studentId: order.student.studentId,
                      phone: order.student.phone,
                      amount: order.totalPrice,
                      transactionId: order.payment!.transactionId!,
                      totalPages: order.totalPages,
                      paperSize: order.config.paperSize,
                      printType: order.config.printType,
                      printSide: order.config.printSide,
                      copies: order.config.copies,
                      submittedAt: order.createdAt,
                    );
                    
                    final path = await ReceiptService.saveReceipt(pdfBytes, order.orderId);
                    
                    if (context.mounted) {
                       ScaffoldMessenger.of(context).hideCurrentSnackBar();
                       ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Receipt saved to $path'),
                          action: SnackBarAction(
                            label: 'Open', 
                            onPressed: () => OpenFilex.open(path),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error generating receipt: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.receipt_long),
                label: const Text('Download Receipt'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildQueueInfoCard(BuildContext context) {
    return GlassCard(
      gradient: LinearGradient(
        colors: [
          AppTheme.warningColor.withOpacity(0.15),
          AppTheme.warningColor.withOpacity(0.05),
        ],
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: AppTheme.warningColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Queue Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your order has been saved locally and will be automatically uploaded when the server becomes available.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.sync, size: 16, color: AppTheme.textMutedDark),
              const SizedBox(width: 8),
              const Text(
                'Auto-retry every 30 seconds',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMutedDark,
                ),
              ),
            ],
          ),
          if (order.retryCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Retry attempts: ${order.retryCount}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMutedDark,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildActionButtons(BuildContext context, bool isQueued) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: GradientButton(
            text: 'Back to Home',
            icon: Icons.home,
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
            ),
          ),
        ),
        if (isQueued) ...[
          const SizedBox(height: AppTheme.spacingSM),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PendingOrdersScreen()),
              ),
              icon: const Icon(Icons.pending_actions),
              label: const Text('View Pending Orders'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _shareOrderDetails(BuildContext context) {
    final text = '''
🖨️ Print Order Details

Order ID: ${order.orderId}
Date: ${formatDate(order.createdAt)}

📄 ${order.files.length} document(s), ${order.totalPages} pages
💰 Total: ${formatCurrency(order.totalPrice)}

Status: ${order.status == 'completed' ? '✅ Submitted' : '⏳ Queued'}
''';
    SharePlus.instance.share(ShareParams(text: text, subject: 'Print Order ${order.orderId}'));
  }
}

