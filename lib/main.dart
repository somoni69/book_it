import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'role_based_home.dart';
import 'core/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/firebase_messaging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализируем локализацию для календаря
  await initializeDateFormatting('ru_RU', null);
  await Firebase.initializeApp();

  await FirebaseMessagingService().initialize();

  await NotificationService().initialize();

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
