import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/providers.dart';
import '../models/order.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(earningsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings Dashboard'),
      ),
      body: earningsAsync.when(
        data: (earnings) => _buildDashboard(context, earnings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, EarningsSummary earnings) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards Row
          Row(
            children: [
              Expanded(
                child: _buildEarningsCard(
                  context,
                  title: 'Today',
                  amount: earnings.today,
                  orders: earnings.ordersToday,
                  color: Colors.green,
                  icon: Icons.today,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildEarningsCard(
                  context,
                  title: 'This Week',
                  amount: earnings.thisWeek,
                  orders: earnings.ordersThisWeek,
                  color: Colors.blue,
                  icon: Icons.calendar_view_week,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildEarningsCard(
                  context,
                  title: 'This Month',
                  amount: earnings.thisMonth,
                  orders: earnings.ordersThisMonth,
                  color: Colors.purple,
                  icon: Icons.calendar_month,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Quick Stats
          const Text(
            'Quick Stats',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildStatRow(
                    'Average Order Value (Today)',
                    earnings.ordersToday > 0
                        ? currencyFormat.format(earnings.today / earnings.ordersToday)
                        : '₹0.00',
                  ),
                  const Divider(),
                  _buildStatRow(
                    'Average Order Value (Month)',
                    earnings.ordersThisMonth > 0
                        ? currencyFormat.format(earnings.thisMonth / earnings.ordersThisMonth)
                        : '₹0.00',
                  ),
                  const Divider(),
                  _buildStatRow(
                    'Total Orders (Month)',
                    '${earnings.ordersThisMonth} orders',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Performance Indicator
          const Text(
            'Performance',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Daily Target Progress'),
                      Text('${earnings.ordersToday} / 50 orders'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (earnings.ordersToday / 50).clamp(0.0, 1.0),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Monthly Revenue Target'),
                      Text('${currencyFormat.format(earnings.thisMonth)} / ₹50,000'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (earnings.thisMonth / 50000).clamp(0.0, 1.0),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsCard(
    BuildContext context, {
    required String title,
    required double amount,
    required int orders,
    required Color color,
    required IconData icon,
  }) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: Colors.white.withOpacity(0.8)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              currencyFormat.format(amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$orders orders',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
