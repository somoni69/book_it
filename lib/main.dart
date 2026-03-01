import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'core/services/firebase_messaging_service.dart';
import 'app/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Загрузка переменных окружения
  await dotenv.load(fileName: ".env");

  // Инициализация локализации для календаря
  await initializeDateFormatting('ru_RU', null);
  await Firebase.initializeApp();

  await FirebaseMessagingService().initialize();
  await NotificationService().initialize();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  
  runApp(const BookItApp());
}

class BookItApp extends StatelessWidget {
  const BookItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter,
      title: 'Book It',
      debugShowCheckedModeBanner: false, // Убираем плашку DEBUG
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue.shade600,
          background: const Color(0xFFF8F9FA), // Единый светлый фон для всех экранов
        ),
        useMaterial3: true,
        // Глобальный стиль AppBar
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          shadowColor: Colors.black.withOpacity(0.05),
        ),
        // Глобальный стиль кнопок
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }
}