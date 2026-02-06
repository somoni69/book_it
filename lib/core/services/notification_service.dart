import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Инициализация уведомлений
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Инициализация timezone для запланированных уведомлений
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dushanbe')); // Таджикистан

    // Android настройки
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS настройки
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  /// Обработчик нажатия на уведомление
  void _onNotificationTapped(NotificationResponse response) {
    // TODO: Навигация при нажатии на уведомление
    // Например, открыть экран записей
  }

  /// Простое уведомление
  Future<void> showSimpleNotification({
    required String title,
    required String body,
    int id = 0,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'booking_channel',
      'Записи',
      channelDescription: 'Уведомления о записях на услуги',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Уведомление клиенту о подтверждении
  Future<void> notifyClientAboutConfirmation({
    required String masterName,
    required String serviceName,
    required DateTime time,
  }) async {
    final timeStr = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    final dateStr = '${time.day}.${time.month}.${time.year}';

    await showSimpleNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: '✅ Запись подтверждена!',
      body:
          'Мастер $masterName подтвердил вашу запись на $serviceName ($dateStr в $timeStr)',
    );
  }

  /// Запланировать напоминание за 1 час до записи
  Future<void> scheduleReminder({
    required String serviceName,
    required DateTime time,
    required bool isForMaster,
  }) async {
    try {
      // Напоминание за 1 час
      final reminderTime = time.subtract(const Duration(hours: 1));

      // Проверяем что время напоминания в будущем
      if (reminderTime.isBefore(DateTime.now())) {
        return; // Слишком поздно напоминать
      }

      final timeStr = '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
      final title = isForMaster
          ? '⏰ Напоминание: У вас запись через 1 час'
          : '⏰ Напоминание о записи';
      final body = isForMaster
          ? 'Клиент записан на $serviceName в $timeStr'
          : 'Не забудьте о записи на $serviceName в $timeStr';

      const androidDetails = AndroidNotificationDetails(
        'reminders_channel',
        'Напоминания',
        channelDescription: 'Напоминания о предстоящих записях',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id: reminderTime.millisecondsSinceEpoch % 100000,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      // Если нет разрешения на точные уведомления - показываем обычное
      if (e.toString().contains('exact_alarms_not_permitted')) {
        final timeStr =
            '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
        await showSimpleNotification(
          title: '⏰ Запись создана',
          body: 'Напоминание о записи на $serviceName в $timeStr',
          id: DateTime.now().millisecondsSinceEpoch % 100000,
        );
      }
      // Игнорируем ошибку, чтобы не блокировать создание записи
    }
  }

  /// Отменить все уведомления
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Отменить конкретное уведомление
  Future<void> cancel(int id) async {
    await _notifications.cancel(id: id);
  }
}
