import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/pages/master_setup_page.dart';
import 'home_wrapper.dart';
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
      final profile = await repo.getUserProfile();

      if (mounted) {
        setState(() {
          _role = profile['role'] ?? 'client';
          _specialtyId = profile['specialty_id'];
          _isLoading = false;
        });
      }
    } catch (e) {
      // ФОЛБЕК: Если ошибка, считаем клиентом
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
    // Плавный переход от экрана загрузки к основному приложению
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _isLoading ? _buildLoadingScreen() : _buildHomeScreen(),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      key: const ValueKey('loading_screen'),
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50, shape: BoxShape.circle),
              child: Icon(Icons.auto_awesome_rounded,
                  size: 64, color: Colors.blue.shade600),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              'Настраиваем рабочее пространство...',
              style: TextStyle(
                  color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeScreen() {
    // ЛОГИКА ВЫБОРА ЭКРАНА
    if (_role == 'master') {
      if (_specialtyId == null) {
        return const MasterSetupPage(key: ValueKey('master_setup'));
      }
      return const MasterHomeScreen(key: ValueKey('master_home'));
    } else {
      // БЫЛО: return const CategoriesPage(key: ValueKey('client_home'));
      // СТАЛО:
      return const HomeWrapper(key: ValueKey('client_home'));
    }
  }
}
