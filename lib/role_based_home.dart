import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/pages/master_setup_page.dart';
import 'features/bookings/data/datasources/booking_remote_datasource.dart';
import 'features/bookings/data/repositories/booking_repository_impl.dart';
import 'features/bookings/presentation/bloc/booking_bloc.dart';
import 'features/bookings/presentation/bloc/booking_event.dart';
import 'features/bookings/presentation/pages/categories_page.dart';
import 'features/bookings/presentation/pages/master_journal_page.dart';

class RoleBasedHome extends StatefulWidget {
  const RoleBasedHome({super.key});

  @override
  State<RoleBasedHome> createState() => _RoleBasedHomeState();
}

class _RoleBasedHomeState extends State<RoleBasedHome> {
  bool _isLoading = true;
  String _role = 'client';
  String? _specialtyId;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    try {
      final repo = AuthRepositoryImpl(Supabase.instance.client);
      // Пытаемся получить профиль
      final profile = await repo.getUserProfile();

      if (mounted) {
        setState(() {
          _role = profile['role'];
          _specialtyId = profile['specialty_id'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ ОШИБКА ПРИ ЗАГРУЗКЕ РОЛИ: $e");

      // ФОЛБЕК: Если ошибка, считаем клиентом и пускаем в приложение
      // чтобы не видеть вечную загрузку
      if (mounted) {
        setState(() {
          _role = 'client';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Инициализация зависимостей
    final supabase = Supabase.instance.client;
    final dataSource = BookingRemoteDataSourceImpl(supabase);
    final repository = BookingRepositoryImpl(dataSource);

    // ЛОГИКА ВЫБОРА ЭКРАНА

    if (_role == 'master') {
      // Проверка: Мастер без специальности -> Настройка
      if (_specialtyId == null) {
        return const MasterSetupPage();
      }

      // У мастера должен быть свой ID (не из сервиса), берем текущего юзера
      // Для Блока нам нужен ID, чье расписание грузить. Мастер грузит СВОЕ.
      final currentUserId = supabase.auth.currentUser!.id;

      return BlocProvider(
        create: (context) =>
            BookingBloc(
              repository: repository,
              masterId: currentUserId, // <--- Мастер смотрит свой журнал
            )..add(
              LoadBookingsForDate(DateTime.now(), 60),
            ), // Дефолт длительность для журнала
        child: const MasterJournalPage(),
      );
    } else {
      // КЛИЕНТ
      // Ему пока не нужен Блок здесь, он получит его внутри BookingPageWrapper
      return const CategoriesPage();
    }
  }
}
