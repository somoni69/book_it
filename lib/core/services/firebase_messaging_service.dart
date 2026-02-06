import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:book_it/core/services/notification_service.dart';
import 'package:book_it/core/utils/user_utils.dart';

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();
  factory FirebaseMessagingService() => _instance;
  FirebaseMessagingService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late FlutterLocalNotificationsPlugin _localNotifications;

  // Инициализация FCM
  Future<void> initialize() async {
    try {
      // Инициализируем Firebase
      await Firebase.initializeApp();

      // Настройка уведомлений
      await _setupNotifications();

      // Запрашиваем разрешения
      await _requestPermissions();

      // Получаем FCM токен
      await _getFCMToken();

      // Настраиваем обработку сообщений
      await _setupMessageHandling();

      debugPrint('✅ FCM инициализирован');
    } catch (e) {
      debugPrint('❌ Ошибка инициализации FCM: $e');
    }
  }

  Future<void> _setupNotifications() async {
    _localNotifications = FlutterLocalNotificationsPlugin();

    // Настройка для Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Настройка для iOS
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings: settings);
  }

  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('Разрешения на уведомления: $settings');
  }

  Future<void> _getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      debugPrint('📱 FCM Token: $token');

      // Сохраняем токен в Supabase
      await _saveTokenToDatabase(token ?? '');
    } catch (e) {
      debugPrint('❌ Ошибка получения FCM токена: $e');
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    try {
      // Получаем ID текущего пользователя
      final userId = UserUtils.getCurrentUserId();
      if (userId == null) return;

      // Сохраняем токен в таблицу user_fcm_tokens
      await Supabase.instance.client.from('user_fcm_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'device_type': 'android',
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ FCM токен сохранен в базу');
    } catch (e) {
      debugPrint('❌ Ошибка сохранения FCM токена: $e');
    }
  }

  Future<void> _setupMessageHandling() async {
    // 1. Сообщение когда приложение в фоне/закрыто
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Сообщение когда приложение открыто
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 3. При клике на уведомление
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '📨 Получено сообщение в foreground: ${message.notification?.title}',
    );

    // Показываем локальное уведомление
    NotificationService().showSimpleNotification(
      title: message.notification?.title ?? 'BookIt',
      body: message.notification?.body ?? 'Новое уведомление',
      payload: message.data['screen'], // Для глубокой навигации
    );
  }

  void _handleNotificationClick(RemoteMessage message) {
    debugPrint('👆 Клик по уведомлению: ${message.data}');

    // Навигация на нужный экран
    final screen = message.data['screen'];
    _navigateToScreen(screen, message.data);
  }

  void _navigateToScreen(String? screen, Map<String, dynamic> data) {
    // TODO: Реализовать навигацию в зависимости от типа уведомления
    // Например: screen = 'booking_details', data = {'booking_id': '123'}
  }
}

// Фоновая обработка сообщений
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  debugPrint('📨 Обработка фонового сообщения: ${message.messageId}');

  // Показываем уведомление даже когда приложение закрыто
  final notificationService = NotificationService();
  await notificationService.initialize();

  await notificationService.showSimpleNotification(
    title: message.notification?.title ?? 'BookIt',
    body: message.notification?.body ?? 'Новое уведомление',
  );
}
