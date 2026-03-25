import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) debugPrint('Background message received: ${message.messageId}');
  await NotificationService._showLocalNotification(message);
}

/// Service for handling Firebase Cloud Messaging (FCM) push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  
  // Stream to notify UI about received notifications
  static final StreamController<RemoteMessage> _notificationStreamController = 
      StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get notificationStream => _notificationStreamController.stream;

  /// Initialize FCM and local notifications
  Future<void> initialize() async {
    // Request permission (iOS and Android 13+)
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token
    await _getFcmToken();

    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    if (kDebugMode) debugPrint('NotificationService initialized. Token: $_fcmToken');
  }

  /// Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: true,
      carPlay: false,
      criticalAlert: false,
    );

    if (kDebugMode) debugPrint('Notification permission status: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    if (kDebugMode) debugPrint('Initializing local notifications...');
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    if (kDebugMode) debugPrint('Local notifications initialized: $initialized');

    // Create notification channel for Android
    if (Platform.isAndroid) {
      if (kDebugMode) debugPrint('Creating Android notification channel...');
      const channel = AndroidNotificationChannel(
        'print_orders', // id
        'Print Order Updates', // name
        description: 'Notifications for print order status updates',
        importance: Importance.max, // Changed to max
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        if (kDebugMode) debugPrint('✅ Notification channel created successfully');
        
        // Request exact alarm permission for Android 12+
        await androidPlugin.requestNotificationsPermission();
        if (kDebugMode) debugPrint('✅ Notification permission requested');
      } else {
        if (kDebugMode) debugPrint('❌ Android plugin is null!');
      }
    }
  }

  /// Get FCM token for this device
  Future<void> _getFcmToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (kDebugMode) debugPrint('FCM Token: $_fcmToken');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        if (kDebugMode) debugPrint('FCM Token refreshed: $newToken');
        // TODO: Send new token to your backend
        _sendTokenToServer(newToken);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting FCM token: $e');
    }
  }

  /// Send FCM token to backend for targeted notifications
  Future<void> _sendTokenToServer(String token) async {
    // TODO: Implement API call to register device token
    // await ApiService.registerDeviceToken(token);
    if (kDebugMode) debugPrint('TODO: Send token to server: $token');
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('=== FOREGROUND MESSAGE RECEIVED ===');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');
    }
    
    // Notify UI listeners
    _notificationStreamController.add(message);
    
    // Show local notification
    _showLocalNotification(message);
  }

  /// Handle notification tap (when app is in background/terminated)
  void _handleNotificationTap(RemoteMessage message) {
    if (kDebugMode) debugPrint('Notification tapped: ${message.data}');
    // TODO: Navigate to relevant screen based on message data
    final orderId = message.data['order_id'];
    if (orderId != null) {
      // Navigate to order status screen
      if (kDebugMode) debugPrint('Navigate to order: $orderId');
    }
  }

  /// Handle local notification tap
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final orderId = data['order_id'];
        if (orderId != null) {
          if (kDebugMode) debugPrint('Navigate to order from local notification: $orderId');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    if (kDebugMode) debugPrint('=== _showLocalNotification called ===');
    final notification = message.notification;
    if (kDebugMode) {
      debugPrint('notification object: $notification');
      debugPrint('notification title: ${notification?.title}');
      debugPrint('notification body: ${notification?.body}');
    }

    // Use notification data or fallback to data payload
    String title = notification?.title ?? message.data['title'] ?? 'Print Order Update';
    String body = notification?.body ?? message.data['body'] ?? 'Your order status has been updated';
    
    if (kDebugMode) {
      debugPrint('Final title: $title');
      debugPrint('Final body: $body');
    }

    try {
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'print_orders',
            'Print Order Updates',
            channelDescription: 'Notifications for print order status updates',
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            // Force heads-up notification
            fullScreenIntent: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
      if (kDebugMode) debugPrint('✅ Local notification shown successfully!');
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ Error showing local notification: $e');
        debugPrint('Stack trace: $stack');
      }
    }
  }

  /// Subscribe to a topic (e.g., for broadcast notifications)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    if (kDebugMode) debugPrint('Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    if (kDebugMode) debugPrint('Unsubscribed from topic: $topic');
  }
}
