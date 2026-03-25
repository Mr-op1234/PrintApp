import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../config/app_config.dart';
import '../models/order.dart';

/// WebSocket Service for real-time order streaming
class WebSocketService {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _intentionalDisconnect = false;

  String _wsUrl;
  String _apiToken;

  // Exponential backoff for reconnection
  Duration _currentBackoff = const Duration(seconds: 1);
  static const Duration _minBackoff = Duration(seconds: 1);
  static const Duration _maxBackoff = Duration(seconds: 60);
  DateTime? _nextRetryTime;

  // Stream controllers
  final _connectionStateController = StreamController<WsConnectionState>.broadcast();
  final _orderController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _retryCountdownController = StreamController<int>.broadcast();

  // Current state
  WsConnectionState _currentState = WsConnectionState.disconnected;

  // Accumulators for streaming data
  final List<int> _pdfBuffer = [];
  Map<String, dynamic>? _currentMetadata;

  WebSocketService({
    required String wsUrl,
    required String apiToken,
  })  : _wsUrl = wsUrl,
        _apiToken = apiToken;

  // Streams
  Stream<WsConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get orderStream => _orderController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<int> get retryCountdownStream => _retryCountdownController.stream;
  WsConnectionState get currentState => _currentState;
  int get nextRetrySeconds => _nextRetryTime != null 
      ? _nextRetryTime!.difference(DateTime.now()).inSeconds.clamp(0, 999)
      : 0;

  /// Update configuration
  void updateConfig({String? wsUrl, String? apiToken}) {
    if (wsUrl != null) _wsUrl = wsUrl;
    if (apiToken != null) _apiToken = apiToken;
  }

  /// Connect to WebSocket server
  Future<void> connect() async {
    if (_currentState == WsConnectionState.connecting) return;

    _intentionalDisconnect = false;
    _updateState(WsConnectionState.connecting);

    try {
      final uri = Uri.parse('$_wsUrl?token=$_apiToken');
      _channel = IOWebSocketChannel.connect(
        uri,
        pingInterval: const Duration(seconds: 30),
      );

      // Listen to incoming messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      // Connection successful - reset backoff
      _currentBackoff = _minBackoff;
      _nextRetryTime = null;
      _updateState(WsConnectionState.connected);
      _startPingTimer();

      print('WebSocket connected to $_wsUrl');
    } catch (e) {
      print('WebSocket connection error: $e');
      _updateState(WsConnectionState.error);
      _errorController.add('Connection failed: $e');
      _scheduleReconnect();
    }
  }

  /// Handle incoming WebSocket messages
  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        // JSON message (metadata, control signals)
        final data = jsonDecode(message) as Map<String, dynamic>;
        final type = data['type'] as String?;

        switch (type) {
          case 'start_file':
            // New file incoming
            _pdfBuffer.clear();
            _currentMetadata = data['metadata'] as Map<String, dynamic>?;
            print('Receiving file: ${data['filename']}');
            // FCM Debug
            print('=== FCM DEBUG [Xerox WebSocket] ===');
            print('Metadata received: ${_currentMetadata != null}');
            if (_currentMetadata != null) {
              print('Metadata keys: ${_currentMetadata!.keys.toList()}');
              print('FCM Token in metadata: ${_currentMetadata!['fcm_token'] != null}');
              if (_currentMetadata!['fcm_token'] != null) {
                final token = _currentMetadata!['fcm_token'] as String;
                print('FCM Token (first 50 chars): ${token.substring(0, token.length > 50 ? 50 : token.length)}...');
              } else {
                print('WARNING: No fcm_token in metadata!');
              }
            }
            break;

          case 'end_file':
            // File complete, emit the order
            if (_currentMetadata != null && _pdfBuffer.isNotEmpty) {
              _orderController.add({
                'metadata': _currentMetadata,
                'pdfBytes': Uint8List.fromList(_pdfBuffer),
              });
              print('File received: ${_pdfBuffer.length} bytes');
            }
            _pdfBuffer.clear();
            _currentMetadata = null;
            break;

          case 'metadata':
            // Standalone metadata
            _currentMetadata = data['data'] as Map<String, dynamic>?;
            break;

          default:
            print('Unknown message type: $type');
        }
      } else if (message is List<int>) {
        // Binary data (PDF chunk)
        _pdfBuffer.addAll(message);
      }
    } catch (e) {
      print('Error processing message: $e');
      _errorController.add('Error processing message: $e');
    }
  }

  /// Handle WebSocket errors
  void _handleError(dynamic error) {
    print('WebSocket error: $error');
    _updateState(WsConnectionState.error);
    _errorController.add('Connection error: $error');
    _scheduleReconnect();
  }

  /// Handle WebSocket disconnection
  void _handleDisconnect() {
    print('WebSocket disconnected');
    _stopPingTimer();

    if (!_intentionalDisconnect) {
      _updateState(WsConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;

    _reconnectTimer?.cancel();
    
    // Calculate next retry time
    _nextRetryTime = DateTime.now().add(_currentBackoff);
    final backoffSeconds = _currentBackoff.inSeconds;
    
    print('Reconnecting in ${backoffSeconds}s (backoff: $_currentBackoff)');
    
    // Start countdown timer
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _nextRetryTime?.difference(DateTime.now()).inSeconds ?? 0;
      if (remaining <= 0 || _currentState == WsConnectionState.connected) {
        timer.cancel();
      } else {
        _retryCountdownController.add(remaining);
      }
    });
    
    _reconnectTimer = Timer(_currentBackoff, () {
      print('Attempting to reconnect...');
      connect();
    });
    
    // Increase backoff for next attempt (exponential, capped at max)
    _currentBackoff = Duration(
      seconds: (_currentBackoff.inSeconds * 2).clamp(
        _minBackoff.inSeconds,
        _maxBackoff.inSeconds,
      ),
    );
  }

  /// Start ping timer to keep connection alive
  void _startPingTimer() {
    _stopPingTimer();
    _pingTimer = Timer.periodic(AppConfig.pingInterval, (_) {
      if (_currentState == WsConnectionState.connected) {
        try {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (e) {
          print('Ping failed: $e');
        }
      }
    });
  }

  /// Stop ping timer
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  /// Update connection state
  void _updateState(WsConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  /// Send a message to the server
  void send(Map<String, dynamic> message) {
    if (_currentState == WsConnectionState.connected) {
      _channel?.sink.add(jsonEncode(message));
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _stopPingTimer();

    await _channel?.sink.close();
    _channel = null;

    _updateState(WsConnectionState.disconnected);
    print('WebSocket disconnected intentionally');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disconnect();
    await _connectionStateController.close();
    await _orderController.close();
    await _errorController.close();
  }
}
