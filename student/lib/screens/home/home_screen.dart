import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../config/theme.dart';
import '../../models/print_order.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/platform_utils.dart';
import '../../services/notification_service.dart';
import '../../services/api_service.dart';
import '../file_selection/file_selection_screen.dart';
import '../pending_orders/pending_orders_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<RemoteMessage>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    // Only show debug notification dialog in debug mode
    if (kDebugMode) {
      _notificationSubscription = NotificationService.notificationStream.listen((message) {
        if (kDebugMode) {
          debugPrint('🔔🔔🔔 HOME SCREEN RECEIVED NOTIFICATION! 🔔🔔🔔');
          debugPrint('Title: ${message.notification?.title}');
          debugPrint('Body: ${message.notification?.body}');
          debugPrint('Data: ${message.data}');
        }
        
        // Show a very visible dialog to confirm notification received (debug only)
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.green, size: 30),
                  SizedBox(width: 10),
                  Text('NOTIFICATION RECEIVED!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Title: ${message.notification?.title ?? "No title"}'),
                  const SizedBox(height: 8),
                  Text('Body: ${message.notification?.body ?? "No body"}'),
                  const SizedBox(height: 8),
                  Text('Data: ${message.data}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverStatus = ref.watch(serverStatusProvider);
    final pendingCount = ref.watch(pendingOrderCountProvider);
    final isDarkMode = ref.watch(themeProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.print, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Print Order',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => ref.read(themeProvider.notifier).toggle(),
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Server Status Card
                  _buildStatusCard(context, serverStatus, ref),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Pending Orders Card (if any)
                  if (pendingCount > 0)
                    _buildPendingOrdersCard(context, pendingCount),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Main Actions
                  _buildMainActionCard(context, serverStatus),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Platform Info
                  _buildPlatformInfo(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, ServerStatus status, WidgetRef ref) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        children: [
          StatusIndicator(
            isOnline: status.isOnline,
            label: status.isOnline ? 'Server Online' : 'Server Offline',
          ),
          const Spacer(),
          if (status.checkedAt != null)
            Text(
              'Checked ${_formatTimeAgo(status.checkedAt!)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMutedDark,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => ref.read(serverStatusProvider.notifier).checkStatus(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildPendingOrdersCard(BuildContext context, int count) {
    return GlassCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PendingOrdersScreen()),
      ),
      gradient: LinearGradient(
        colors: [
          AppTheme.warningColor.withOpacity(0.2),
          AppTheme.warningColor.withOpacity(0.1),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.pending_actions,
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Pending Order${count > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Will retry automatically when server is available',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMutedDark,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppTheme.warningColor,
          ),
        ],
      ),
    ).animate()
        .fadeIn(duration: 400.ms, delay: 100.ms)
        .slideX(begin: -0.1, end: 0)
        .then()
        .shimmer(duration: 2000.ms, color: AppTheme.warningColor.withOpacity(0.3));
  }



  Widget _buildMainActionCard(BuildContext context, ServerStatus status) {
    return GlassCard(
      onTap: status.isOnline || true // Allow offline queueing
          ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FileSelectionScreen()),
              )
          : null,
      padding: const EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.glowShadow,
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 40,
            ),
          ).animate()
              .scale(duration: 400.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(duration: 2000.ms, color: Colors.white24),
          const SizedBox(height: AppTheme.spacingMD),
          const Text(
            'New Print Order',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            'Select PDFs, configure print settings, and submit your order',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMutedDark,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),
          if (!status.isOnline)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSM,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: const Text(
                'Offline mode - Orders will be queued',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.warningColor,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.1, end: 0);
  }



  Widget _buildPlatformInfo(BuildContext context) {
    final fcmToken = NotificationService().fcmToken;
    
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getPlatformIcon(),
                size: 24,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Text(
                'Running on ${PlatformUtils.platformName}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          // Only show FCM debug info in debug mode
          if (kDebugMode) ...[
            const SizedBox(height: AppTheme.spacingSM),
            // FCM Token Debug Info
            GestureDetector(
              onTap: () {
                if (fcmToken != null) {
                  Clipboard.setData(ClipboardData(text: fcmToken));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('FCM Token copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: fcmToken != null 
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Row(
                  children: [
                    Icon(
                      fcmToken != null ? Icons.notifications_active : Icons.notifications_off,
                      size: 16,
                      color: fcmToken != null ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fcmToken != null 
                            ? 'FCM: ${fcmToken.substring(0, fcmToken.length > 30 ? 30 : fcmToken.length)}... (tap to copy)'
                            : 'FCM Token: NOT AVAILABLE',
                        style: TextStyle(
                          fontSize: 11,
                          color: fcmToken != null ? AppTheme.successColor : AppTheme.errorColor,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            // Test Notification Button (debug only)
            ElevatedButton.icon(
              onPressed: fcmToken != null ? () => _testNotification(context, fcmToken) : null,
              icon: const Icon(Icons.bug_report, size: 16),
              label: const Text('Test FCM Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 500.ms);
  }

  Future<void> _testNotification(BuildContext context, String fcmToken) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sending test notification...')),
    );
    
    try {
      // Call backend test endpoint
      final response = await ApiService.testNotification(fcmToken);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backend response: $response'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getPlatformIcon() {
    if (PlatformUtils.isWeb) return Icons.language;
    if (PlatformUtils.isMobile) return Icons.phone_android;
    return Icons.desktop_windows;
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
