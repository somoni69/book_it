import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:book_it/features/auth/presentation/pages/login_page.dart';
import 'package:book_it/features/bookings/presentation/pages/master_home_screen.dart';
import 'package:book_it/features/bookings/presentation/pages/booking_details_screen.dart'; // Этого экрана может не быть - создадим позже
import 'package:book_it/features/bookings/presentation/pages/master_today_bookings_screen.dart';
import 'package:book_it/features/bookings/presentation/pages/master_journal_page.dart';
import 'package:book_it/role_based_home.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  
)