import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';

class NotificationRouter {
  static final NotificationRouter _instance = NotificationRouter._internal();
  factory NotificationRouter() => _instance;
  NotificationRouter._internal();

  void navigateToScreen(String? screen, Map<String, dynamic> data) {
    final context = rootNavigatorKey.currentContext;
    if (context == null || screen == null) {
      debugPrint('❌ Navigator context не доступен');
      return;
    }

    final id = data['id'] as String?;

    switch (screen) {
      case 'booking_details':
        if (id != null) {
          context.go('/booking/$id');
        } else {
          context.go('/today');
        }
        break;

      case 'today_bookings':
        context.go('/today');
        break;

      case 'master_journal':
      case 'journal':
        context.go('/journal');
        break;

      case 'reviews':
        debugPrint('Navigate to reviews - в разработке');
        break;

      case 'profile':
        debugPrint('Navigate to profile - в разработке');
        break;

      default:
        context.go('/master');
        debugPrint('Unknown notification screen: $screen, going to /master');
    }
  }
}
