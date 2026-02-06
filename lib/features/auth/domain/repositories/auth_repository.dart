import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { client, master }

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password, String fullName);
  Future<void> signOut();
  String? get currentUserId;
  Future<String> getUserRole();

  Future<Map<String, dynamic>> getProfile(String profileId);
  Future<void> updateProfile({
    required String profileId,
    required Map<String, dynamic> updates,
  });
  Future<String> getCurrentUserId();

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    UserRole? role,
  });
}
