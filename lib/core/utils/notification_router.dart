import 'package:flutter/material.dart';

class NotificationRouter {
  static final NotificationRouter _instance = NotificationRouter._internal();
  factory NotificationRouter() => _instance;
  NotificationRouter._internal();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  void navigateToScreen(String? screen, Map<String, dynamic> data) {
    if (screen == null || navigatorKey.currentContext == null) return;

    final context = navigatorKey.currentContext!;

    switch (screen) {
      case 'booking_details':
        final bookingId = data['booking_id'] as String?;
        if (bookingId != null) {
          _navigateToBookingDetails(context, bookingId);
        }
        break;

      case 'master_journal':
        _navigateToMasterJournal(context);
        break;

      case 'today_bookings':
        _navigateToTodayBookings(context);
        break;

      case 'reviews':
        _navigateToReviews(context);
        break;

      case 'profile':
        _navigateToProfile(context);
        break;

      default:
        debugPrint('Unknown notification screen: $screen');
    }
  }

  void _navigateToBookingDetails(BuildContext context, String bookingId) {
    // TODO: Navigate to booking details screen
    debugPrint('Navigate to booking details: $bookingId');
  }

  void _navigateToMasterJournal(BuildContext context) {
    // TODO: Navigate to master journal
    debugPrint('Navigate to master journal');
  }

  void _navigateToTodayBookings(BuildContext context) {
    // TODO: Navigate to today bookings
    debugPrint('Navigate to today bookings');
  }

  void _navigateToReviews(BuildContext context) {
    // TODO: Navigate to reviews
    debugPrint('Navigate to reviews');
  }

  void _navigateToProfile(BuildContext context) {
    // TODO: Navigate to profile
    debugPrint('Navigate to profile');
  }
}
