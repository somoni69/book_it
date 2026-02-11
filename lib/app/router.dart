import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../role_based_home.dart';
import '../features/bookings/presentation/pages/master_today_bookings_screen.dart';
import '../features/bookings/presentation/pages/master_journal_page.dart';
import '../features/bookings/presentation/pages/create_booking_screen.dart';
import '../features/bookings/presentation/bloc/create_booking_bloc.dart';
import '../features/bookings/presentation/pages/reminders_management_screen.dart';
import '../features/bookings/presentation/bloc/reminders_bloc.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null;
    final isLoggingIn = state.matchedLocation == '/login';

    if (!isLoggedIn && !isLoggingIn) {
      return '/login';
    }

    if (isLoggedIn && isLoggingIn) {
      return '/master';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/master',
      builder: (context, state) => const RoleBasedHome(),
    ),
    GoRoute(
      path: '/today',
      builder: (context, state) => const MasterTodayBookingsScreen(),
    ),
    GoRoute(
      path: '/journal',
      builder: (context, state) => const MasterJournalPage(),
    ),
    GoRoute(
      path: '/booking/:id',
      builder: (context, state) {
        final bookingId = state.pathParameters['id'] ?? '';
        return Scaffold(
          appBar: AppBar(title: const Text('Детали записи')),
          body: Center(
            child: Text('Запись ID: $bookingId\n\nВ разработке'),
          ),
        );
      },
    ),
    GoRoute(
      path: '/create-booking',
      name: 'create_booking',
      builder: (context, state) {
        final masterId = Supabase.instance.client.auth.currentUser?.id ?? '';
        return BlocProvider(
          create: (context) => CreateBookingBloc(
            supabase: Supabase.instance.client,
            masterId: masterId,
          )..add(LoadInitialData(masterId)),
          child: const CreateBookingScreen(),
        );
      },
    ),
    GoRoute(
      path: '/reminders',
      name: 'reminders',
      builder: (context, state) {
        final masterId = Supabase.instance.client.auth.currentUser?.id ?? '';
        return BlocProvider(
          create: (context) => RemindersBloc(
            supabase: Supabase.instance.client,
          ),
          child: RemindersManagementScreen(masterId: masterId),
        );
      },
    ),
  ],
);
