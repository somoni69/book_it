import 'package:supabase_flutter/supabase_flutter.dart';

class UserUtils {
  static String getCurrentUserIdOrThrow() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authorized');
    }
    return user.id;
  }

  static String? getCurrentUserId() {
    return Supabase.instance.client.auth.currentUser?.id;
  }

  static bool isAuthenticated() {
    return Supabase.instance.client.auth.currentUser != null;
  }

  static String getCurrentUserEmail() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authorized');
    }
    return user.email ?? '';
  }
}
