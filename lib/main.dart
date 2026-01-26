import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/bookings/data/datasources/booking_remote_datasource.dart';
import 'features/bookings/data/repositories/booking_repository_impl.dart';
import 'features/bookings/presentation/bloc/booking_bloc.dart';
import 'features/bookings/presentation/bloc/booking_event.dart';
import 'home_wrapper.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'role_based_home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://pxkmhblwjjwirpsvmgdb.supabase.co',
    anonKey: 'sb_publishable_RTUaRjY7LszEuXw870VjuA_FzjOwltP',
  );
  runApp(const BookItApp());
}

class BookItApp extends StatelessWidget {
  const BookItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book It',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session;

          if (session != null) {
            // Юзер залогинен -> Пусть Роутер решает, куда его пустить
            return const RoleBasedHome();
          } else {
            return const LoginPage();
          }
        },
      ),
    );
  }
}
