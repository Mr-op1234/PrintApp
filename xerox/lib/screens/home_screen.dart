import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../providers/providers.dart';
import '../services/file_service.dart';
import '../widgets/order_card.dart';
import '../widgets/connection_indicator.dart';
import 'settings_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  DateTime? _filterFromDate;
  DateTime? _filterToDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Connect to WebSocket on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wsServiceProvider).connect();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleServicePause(WidgetRef ref, bool currentlyPaused) async {
    final settings = ref.read(settingsProvider);
    final notifier = ref.read(servicePausedProvider.notifier);
    
    try {
      final success = await notifier.togglePause(
        settings.wsUrl.replaceAll('wss://', 'https://').replaceAll('/ws/xerox', ''),
        settings.apiToken,
        !currentlyPaused,
      );
      
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyPaused ? 'Service resumed' : 'Service paused'),
            backgroundColor: currentlyPaused ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.print, size: 28),
            SizedBox(width: 12),
            Text('Xerox Manager'),
          ],
        ),
        actions: [
          const ConnectionIndicator(),
          const SizedBox(width: 16),
          // Pause/Resume Service Button
          Consumer(
            builder: (context, ref, _) {
              final isPaused = ref.watch(servicePausedProvider);
              return IconButton(
                icon: Icon(
                  isPaused ? Icons.play_arrow : Icons.pause,
                  color: isPaused ? Colors.orange : null,
                ),
                tooltip: isPaused ? 'Resume Service' : 'Pause Service',
                onPressed: () => _toggleServicePause(ref, isPaused),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: 'Earnings Dashboard',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pending_actions),
                  const SizedBox(width: 8),
                  const Text('Pending Orders'),
                  const SizedBox(width: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final orders = ref.watch(pendingOrdersProvider);
                      if (orders.isEmpty) return const SizedBox();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${orders.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle),
                  SizedBox(width: 8),
                  Text('Completed'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildCompletedTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    final orders = ref.watch(pendingOrdersProvider);

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No pending orders',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Orders will appear here when received',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isFirst = index == 0;
        return OrderCard(
          order: order,
          isFirstInQueue: isFirst,
          queuePosition: index + 1,
          onPrint: () => _handlePrint(order),
          onOpen: () => _handleOpen(order),
          onComplete: () => _handleComplete(order),
          onDelete: () => _handleDelete(order),
        );
      },
    );
  }

  Widget _buildCompletedTab() {
    return Column(
      children: [
        // Search and Filter Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Order ID or Student Name',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_filterFromDate != null
                    ? DateFormat('dd/MM').format(_filterFromDate!)
                    : 'From'),
                onPressed: () => _selectDate(true),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(_filterToDate != null
                    ? DateFormat('dd/MM').format(_filterToDate!)
                    : 'To'),
                onPressed: () => _selectDate(false),
              ),
              const SizedBox(width: 8),
              if (_filterFromDate != null || _filterToDate != null || _searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _filterFromDate = null;
                      _filterToDate = null;
                    });
                  },
                ),
            ],
          ),
        ),
        // Orders List
        Expanded(
          child: ref
              .watch(completedOrdersProvider(OrderFilter(
                fromDate: _filterFromDate,
                toDate: _filterToDate,
                searchQuery: _searchController.text.isEmpty ? null : _searchController.text,
              )))
              .when(
                data: (orders) {
                  if (orders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No completed orders',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return OrderCard(
                        order: order,
                        isCompleted: true,
                        onOpen: () => _handleOpen(order),
                        onDelete: () => _handleDelete(order),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
        ),
      ],
    );
  }

  Future<void> _selectDate(bool isFrom) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        if (isFrom) {
          _filterFromDate = date;
        } else {
          _filterToDate = date;
        }
      });
    }
  }

  void _handlePrint(PrintOrder order) {
    ref.read(pendingOrdersProvider.notifier).printOrder(order.orderId);
  }

  void _handleOpen(PrintOrder order) async {
    try {
      // Import FileService statically at top of file
      await FileService.openPdf(order.localFilePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  void _handleComplete(PrintOrder order) async {
    // Show FCM debug info in a dialog
    final fcmToken = order.fcmToken;
    final hasToken = fcmToken != null && fcmToken.isNotEmpty;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order: ${order.orderId}'),
            Text('Student: ${order.studentName}'),
            const SizedBox(height: 16),
            const Text('FCM Notification Status:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasToken ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: hasToken ? Colors.green : Colors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasToken ? Icons.check_circle : Icons.error,
                        color: hasToken ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasToken ? 'FCM Token Available' : 'NO FCM Token!',
                        style: TextStyle(
                          color: hasToken ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (hasToken) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Token: ${fcmToken!.substring(0, fcmToken.length > 40 ? 40 : fcmToken.length)}...',
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Student will NOT receive notification!\nOrder was submitted without FCM token.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete & Notify'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      ref.read(pendingOrdersProvider.notifier).markComplete(order.orderId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order ${order.orderId} marked as complete'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleDelete(PrintOrder order) async {
    String selectedReason = "Order was not processed";
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Delete Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to delete order ${order.orderId}?\n\nThe student will be notified that their order was rejected.'),
              const SizedBox(height: 16),
              const Text('Rejection Reason:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: "Order was not processed", child: Text("Order was not processed")),
                  DropdownMenuItem(value: "Invalid payment screenshot", child: Text("Invalid payment screenshot")),
                  DropdownMenuItem(value: "Document file corrupted", child: Text("Document file corrupted")),
                  DropdownMenuItem(value: "Duplicate order", child: Text("Duplicate order")),
                  DropdownMenuItem(value: "Student request", child: Text("Student request")),
                  DropdownMenuItem(value: "Other", child: Text("Other")),
                ],
                onChanged: (value) {
                  setState(() => selectedReason = value ?? selectedReason);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete & Notify'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      ref.read(pendingOrdersProvider.notifier).deleteOrder(order.orderId, reason: selectedReason);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order ${order.orderId} deleted. Student notified.')),
      );
    }
  }
}
