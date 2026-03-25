import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../config/app_config.dart';

class OrderCard extends StatelessWidget {
  final PrintOrder order;
  final bool isCompleted;
  final bool isFirstInQueue;
  final int? queuePosition;
  final VoidCallback? onPrint;
  final VoidCallback? onOpen;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;

  const OrderCard({
    super.key,
    required this.order,
    this.isCompleted = false,
    this.isFirstInQueue = true,
    this.queuePosition,
    this.onPrint,
    this.onOpen,
    this.onComplete,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Queue position badge for pending orders
                    if (!isCompleted && queuePosition != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isFirstInQueue ? Colors.green : Colors.grey[400],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '#$queuePosition',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _getStatusColor(order.status)),
                      ),
                      child: Text(
                        order.orderId,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(order.status),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(order.status),
                  ],
                ),
                Text(
                  currencyFormat.format(order.totalCost),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Student Info
            Row(
              children: [
                const Icon(Icons.person, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  order.studentName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Text(
                  order.studentId,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Phone
            Row(
              children: [
                const Icon(Icons.phone, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(order.phone),
              ],
            ),
            const SizedBox(height: 12),

            // Print Config
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildConfigItem(Icons.description, '${order.totalPages} pages'),
                  _buildConfigItem(
                    order.printType == 'COLOR' ? Icons.palette : Icons.format_color_text,
                    order.printType == 'COLOR' ? 'Color' : 'B&W',
                  ),
                  _buildConfigItem(
                    order.printSide == 'DOUBLE' ? Icons.content_copy : Icons.description,
                    order.printSide == 'DOUBLE' ? 'Double' : 'Single',
                  ),
                  _buildConfigItem(Icons.copy_all, '${order.copies}x copies'),
                ],
              ),
            ),
            const SizedBox(height: 12),


            // Timestamp
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  isCompleted && order.completedAt != null
                      ? 'Completed: ${dateFormat.format(order.completedAt!)}'
                      : 'Received: ${dateFormat.format(order.receivedAt)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            
            // Transaction ID (if verified)
            if (order.isVerified && order.transactionId != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Txn ID: ${order.transactionId}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],

            // Error message if any
            if (order.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      order.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Queue waiting message for non-first items
            if (!isCompleted && !isFirstInQueue && queuePosition != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty, size: 18, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Waiting in queue. Complete order #${queuePosition! - 1} first.',
                      style: TextStyle(color: Colors.amber[900], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isCompleted && onPrint != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                    onPressed: isFirstInQueue ? onPrint : null,
                    style: !isFirstInQueue ? ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.grey[600],
                    ) : null,
                  ),
                const SizedBox(width: 8),
                if (onOpen != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open'),
                    onPressed: (!isCompleted && !isFirstInQueue) ? null : onOpen,
                    style: (!isCompleted && !isFirstInQueue) ? OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ) : null,
                  ),
                const SizedBox(width: 8),
                if (!isCompleted && onComplete != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Complete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isFirstInQueue ? Colors.green : Colors.grey,
                    ),
                    onPressed: isFirstInQueue ? onComplete : null,
                  ),
                const SizedBox(width: 8),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: onDelete,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayName,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.printing:
        return Colors.blue;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.error:
        return Colors.red;
    }
  }
}
