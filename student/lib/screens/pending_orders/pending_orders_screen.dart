import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../models/print_order.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../services/retry_service.dart';
import '../../utils/helpers.dart';

class PendingOrdersScreen extends ConsumerStatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  ConsumerState<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends ConsumerState<PendingOrdersScreen> {
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    ref.read(pendingOrdersProvider.notifier).refresh();
  }

  Future<void> _retryAll() async {
    setState(() => _isRetrying = true);
    await RetryService.retryNow();
    ref.read(pendingOrdersProvider.notifier).refresh();
    setState(() => _isRetrying = false);
  }

  Future<void> _retrySingle(String orderId) async {
    setState(() => _isRetrying = true);
    final success = await RetryService.retrySingleOrder(orderId);
    ref.read(pendingOrdersProvider.notifier).refresh();
    setState(() => _isRetrying = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Order uploaded successfully!' : 'Upload failed. Will retry later.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber, color: AppTheme.warningColor),
            SizedBox(width: 12),
            Text('Cancel Order?'),
          ],
        ),
        content: const Text(
          'This will permanently remove the order from the queue. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await RetryService.cancelOrder(orderId);
      ref.read(pendingOrdersProvider.notifier).refresh();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingOrders = ref.watch(pendingOrdersProvider);
    final serverStatus = ref.watch(serverStatusProvider);
    final retryStatus = ref.watch(retryStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(pendingOrdersProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Server Status Banner
          _buildServerStatusBanner(serverStatus),

          // Retry Status
          retryStatus.when(
            data: (status) => _buildRetryStatusBanner(status),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Orders List
          Expanded(
            child: pendingOrders.isEmpty
                ? _buildEmptyState()
                : _buildOrdersList(pendingOrders),
          ),
        ],
      ),
      floatingActionButton: pendingOrders.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isRetrying || !serverStatus.isOnline ? null : _retryAll,
              backgroundColor: serverStatus.isOnline
                  ? AppTheme.primaryColor
                  : AppTheme.surfaceBorder,
              icon: _isRetrying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(_isRetrying ? 'Retrying...' : 'Retry All'),
            )
          : null,
    );
  }

  Widget _buildServerStatusBanner(ServerStatus status) {
    // Determine the actual status to display
    final bool canSubmit = status.canSubmitOrders;
    final String statusLabel;
    final Color statusColor;
    
    if (!status.isOnline) {
      statusLabel = 'Server Offline';
      statusColor = AppTheme.errorColor;
    } else if (!status.isXeroxOnline) {
      statusLabel = 'Xerox Offline';
      statusColor = AppTheme.errorColor;
    } else if (!status.isAcceptingOrders) {
      statusLabel = 'Not Accepting Orders';
      statusColor = AppTheme.warningColor;
    } else if (status.isPaused) {
      statusLabel = 'Service Paused';
      statusColor = AppTheme.warningColor;
    } else {
      statusLabel = 'Ready to Print';
      statusColor = AppTheme.successColor;
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      color: statusColor.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          StatusIndicator(
            isOnline: canSubmit,
            label: statusLabel,
          ),
          if (!canSubmit) ...[
            const SizedBox(width: 12),
            const Text(
              '• Auto-retry in 30s',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRetryStatusBanner(RetryStatus status) {
    if (!status.isRetrying) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingSM),
      color: AppTheme.primaryColor.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            status.message ?? 'Processing...',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.check_circle_outline,
      title: 'All Caught Up!',
      description: 'No pending orders. All your orders have been successfully uploaded.',
      action: TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Go Back'),
      ),
    );
  }

  Widget _buildOrdersList(List<PrintOrder> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(order, index + 1, orders.length);
      },
    );
  }

  Widget _buildOrderCard(PrintOrder order, int position, int total) {
    final timeSinceCreation = DateTime.now().difference(order.createdAt);
    
    return GlassCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: _getStatusColor(order).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusLG - 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getStatusColor(order).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#$position',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(order),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderId,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        'Position $position of $total in queue',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMutedDark,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(order),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(Icons.person, order.student.name),
                    _buildInfoItem(Icons.description, '${order.files.length} file(s)'),
                    _buildInfoItem(Icons.layers, '${order.totalPages} pages'),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatCurrency(order.totalPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.successColor,
                      ),
                    ),
                    Text(
                      _formatDuration(timeSinceCreation),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMutedDark,
                      ),
                    ),
                  ],
                ),
                if (order.errorMessage != null) ...[
                  const SizedBox(height: AppTheme.spacingSM),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: AppTheme.errorColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.errorMessage!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (order.retryCount > 0) ...[
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    'Retry attempts: ${order.retryCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMutedDark,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.surfaceBorder),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _cancelOrder(order.orderId),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isRetrying ? null : () => _retrySingle(order.orderId),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: position * 100))
        .slideX(begin: 0.1, end: 0);
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMutedDark),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatusChip(PrintOrder order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(order).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStatusText(order),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _getStatusColor(order),
        ),
      ),
    );
  }

  Color _getStatusColor(PrintOrder order) {
    if (order.retryCount >= 3) return AppTheme.errorColor;
    if (order.retryCount > 0) return AppTheme.warningColor;
    return AppTheme.infoColor;
  }

  String _getStatusText(PrintOrder order) {
    if (order.retryCount >= 3) return 'Failing';
    if (order.retryCount > 0) return 'Retrying';
    return 'Pending';
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays}d ago';
    if (duration.inHours > 0) return '${duration.inHours}h ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m ago';
    return 'Just now';
  }
}
