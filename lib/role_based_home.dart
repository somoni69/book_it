import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/pages/master_setup_page.dart';
import 'features/bookings/presentation/pages/categories_page.dart';
import 'features/bookings/presentation/pages/master_home_screen.dart';

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

    // ЛОГИКА ВЫБОРА ЭКРАНА

    if (_role == 'master') {
      // Проверка: Мастер без специальности -> Настройка
      if (_specialtyId == null) {
        return const MasterSetupPage();
      }

      // Мастер с заполненной специальностью -> Главный экран мастера
      return const MasterHomeScreen();
    } else {
      // КЛИЕНТ
      return const CategoriesPage();
    }
  }
}
