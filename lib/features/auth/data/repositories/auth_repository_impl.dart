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
      print("⚠️ User ID is null");
      return 'client';
    }

    print("🔍 Проверяю роль для ID: $userId");

    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      final role = response['role'] as String;
      print("✅ Роль из базы: $role");
      return role;
    } catch (e) {
      print("❌ ОШИБКА ПОЛУЧЕНИЯ РОЛИ: $e");
      return 'client';
    }
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
        .eq('category_id', categoryId) // <--- ФИЛЬТР
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }
}
