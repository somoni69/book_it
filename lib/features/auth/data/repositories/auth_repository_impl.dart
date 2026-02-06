import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient supabase;

  AuthRepositoryImpl(this.supabase);

  @override
  Stream<User?> get authStateChanges =>
      supabase.auth.onAuthStateChange.map((event) => event.session?.user);

  @override
  String? get currentUserId => supabase.auth.currentUser?.id;

  @override
  Future<void> signIn(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp(String email, String password, String fullName) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  @override
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // 1. Отправить код на почту (или ссылку)
  Future<void> sendOtp(String email) async {
    // Supabase отправит 6-значный код на email
    await supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser:
          false, // Если юзера нет - ошибка (пусть сначала регается)
    );
  }

  // 2. Регистрация + Отправка кода
  // Мы передаем данные (имя, роль) сразу, чтобы Триггер их подхватил
  Future<void> signUpWithOtp(String email, String fullName, String role) async {
    await supabase.auth.signInWithOtp(
      email: email,
      data: {
        'full_name': fullName,
        'role': role, // <--- ВОТ ОНО! Передаем роль в базу
      },
      shouldCreateUser: true, // Создаем, если нет
    );
  }

  // 3. Проверка кода (Вход)
  Future<void> verifyOtp(String email, String token) async {
    await supabase.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  @override
  Future<String> getUserRole() async {
    final userId = currentUserId;
    if (userId == null) {
      return 'client';
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      final role = response['role'] as String;
      return role;
    } catch (e) {
      return 'client';
    }
  }

  @override
  Future<Map<String, dynamic>> getProfile(String profileId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('*')
          .eq('id', profileId)
          .single();

      return response;
    } on PostgrestException catch (e) {
      throw Exception('Ошибка загрузки профиля: ${e.message}');
    }
  }

  @override
  Future<void> updateProfile({
    required String profileId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await supabase.from('profiles').update(updates).eq('id', profileId);
    } on PostgrestException catch (e) {
      throw Exception('Ошибка обновления профиля: ${e.message}');
    }
  }

  @override
  Future<String> getCurrentUserId() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }
    return user.id;
  }

  Future<List<Map<String, dynamic>>> getSpecialties() async {
    final response = await supabase
        .from('specialties')
        .select('id, name, categories(name)') // Подтягиваем имя категории
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateMasterSpecialty(String specialtyId) async {
    final userId = currentUserId;
    if (userId == null) return;

    await supabase
        .from('profiles')
        .update({'specialty_id': specialtyId})
        .eq('id', userId);
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return {'role': 'client'};

    final response = await supabase
        .from('profiles')
        .select('role, specialty_id')
        .eq('id', userId)
        .single();
    return response;
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await supabase
        .from('categories')
        .select('id, name, icon')
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getSpecialtiesByCategory(
    String categoryId,
  ) async {
    final response = await supabase
        .from('specialties')
        .select('id, name')
        .eq('category_id', categoryId)
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    UserRole? role,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': role?.name ?? 'client'},
      );

      if (response.user == null) {
        throw Exception('Registration failed: user not created');
      }

      await Future.delayed(const Duration(seconds: 1));

      if (role == UserRole.master) {
        await _createMasterOrganization(response.user!.id, fullName);
      }
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Registration error: $e');
    }
  }

  Future<void> registerMaster({
    required String email,
    required String password,
    required String fullName,
    required String specialtyId,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': 'master'},
      );

      if (response.user == null) {
        throw Exception('Registration failed');
      }

      final userId = response.user!.id;
      await Future.delayed(const Duration(seconds: 1));

      await supabase
          .from('profiles')
          .update({'role': 'master', 'specialty_id': specialtyId})
          .eq('id', userId);

      final orgResponse = await supabase
          .from('organizations')
          .insert({
            'name': '$fullName Studio',
            'owner_id': userId,
            'type': 'individual',
          })
          .select('id')
          .single();

      final orgId = orgResponse['id'] as String;

      await supabase
          .from('profiles')
          .update({'organization_id': orgId})
          .eq('id', userId);

      await _createDefaultServices(userId, specialtyId, orgId);
      await _createDefaultWorkingHours(userId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _createMasterOrganization(
    String masterId,
    String masterName,
  ) async {
    try {
      await supabase.from('organizations').insert({
        'name': 'Salon $masterName',
        'owner_id': masterId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Non-blocking
    }
  }

  Future<void> _createDefaultServices(
    String masterId,
    String specialtyId,
    String orgId,
  ) async {
    final services = _getDefaultServicesForSpecialty(specialtyId);

    for (final service in services) {
      await supabase.from('services').insert({
        'master_id': masterId,
        'organization_id': orgId,
        'name': service['name'],
        'duration_minutes': service['duration_minutes'],
        'price': service['price'],
        'currency': 'TJS',
        'is_active': true,
      });
    }
  }

  List<Map<String, dynamic>> _getDefaultServicesForSpecialty(
    String specialtyId,
  ) {
    return [
      {'name': 'Main Service', 'duration_minutes': 60, 'price': 200.0},
    ];
  }

  Future<void> _createDefaultWorkingHours(String masterId) async {
    final workingHours = List.generate(7, (index) {
      final isDayOff = index >= 5;

      return {
        'master_id': masterId,
        'day_of_week': index + 1,
        'start_time': '09:00:00',
        'end_time': '18:00:00',
        'is_day_off': isDayOff,
        'is_active': true,
      };
    });

    await supabase.from('working_hours').insert(workingHours);
  }
}
