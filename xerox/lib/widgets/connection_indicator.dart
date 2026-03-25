import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../models/order.dart';

class ConnectionIndicator extends ConsumerWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionStateProvider);

    return connectionAsync.when(
      data: (state) => _buildIndicator(context, state),
      loading: () => _buildIndicator(context, WsConnectionState.connecting),
      error: (_, __) => _buildIndicator(context, WsConnectionState.error),
    );
  }

  Widget _buildIndicator(BuildContext context, WsConnectionState state) {
    final color = _getColor(state);
    final text = _getText(state);
    final icon = _getIcon(state);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Color _getColor(WsConnectionState state) {
    switch (state) {
      case WsConnectionState.connected:
        return Colors.green;
      case WsConnectionState.connecting:
        return Colors.orange;
      case WsConnectionState.disconnected:
        return Colors.grey;
      case WsConnectionState.error:
        return Colors.red;
    }
  }

  String _getText(WsConnectionState state) {
    switch (state) {
      case WsConnectionState.connected:
        return '🟢 Connected';
      case WsConnectionState.connecting:
        return '🟡 Connecting...';
      case WsConnectionState.disconnected:
        return '🔴 Disconnected';
      case WsConnectionState.error:
        return '🔴 Error';
    }
  }

  IconData _getIcon(WsConnectionState state) {
    switch (state) {
      case WsConnectionState.connected:
        return Icons.wifi;
      case WsConnectionState.connecting:
        return Icons.sync;
      case WsConnectionState.disconnected:
        return Icons.wifi_off;
      case WsConnectionState.error:
        return Icons.error_outline;
    }
  }
}
