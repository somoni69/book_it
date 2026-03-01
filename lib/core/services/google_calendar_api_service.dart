import 'dart:async';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class GoogleCalendarApiService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: Platform.isAndroid
        ? '797916119460-1qr4bc9dqra0lt66isie3nlcmfdis0mm.apps.googleusercontent.com'
        : '797916119460-1qr4bc9dqra0lt66isie3nlcmfdis0mm.apps.googleusercontent.com',
    scopes: [CalendarApi.calendarEventsScope],
  );

  // Проверка, подключен ли аккаунт
  static Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  // Получить текущего пользователя
  static Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
  }

  // Вход / подключение аккаунта
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      return null;
    }
  }

  // Выход / отключение
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  // Получить аутентифицированный HTTP-клиент для Calendar API
  static Future<http.Client?> getAuthenticatedClient() async {
    final account = await getCurrentUser();
    if (account == null) return null;
    // The extension adds authenticatedClient() method to GoogleSignInAccount
    return (account as dynamic).authenticatedClient() as http.Client?;
  }

  // Создать событие в календаре
  static Future<String?> createEvent({
    required String summary,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
  }) async {
    final client = await getAuthenticatedClient();
    if (client == null) return null;

    final calendarApi = CalendarApi(client);
    final event = Event()
      ..summary = summary
      ..description = description
      ..location = location;

    final startEventDateTime = EventDateTime()
      ..dateTime = startTime.toUtc()
      ..timeZone = 'Asia/Dushanbe';
    event.start = startEventDateTime;

    final endEventDateTime = EventDateTime()
      ..dateTime = endTime.toUtc()
      ..timeZone = 'Asia/Dushanbe';
    event.end = endEventDateTime;

    try {
      final createdEvent = await calendarApi.events.insert(event, 'primary');
      return createdEvent.id;
    } catch (e) {
      print('❌ Ошибка создания события: $e');
      return null;
    } finally {
      client.close();
    }
  }

  // Обновить событие
  static Future<bool> updateEvent({
    required String eventId,
    String? summary,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
  }) async {
    final client = await getAuthenticatedClient();
    if (client == null) return false;

    final calendarApi = CalendarApi(client);
    try {
      // Сначала получаем существующее событие
      var event = await calendarApi.events.get(eventId, 'primary');

      if (summary != null) event.summary = summary;
      if (description != null) event.description = description;
      if (location != null) event.location = location;
      if (startTime != null) {
        final startEventDateTime = EventDateTime()
          ..dateTime = startTime.toUtc()
          ..timeZone = 'Asia/Dushanbe';
        event.start = startEventDateTime;
      }
      if (endTime != null) {
        final endEventDateTime = EventDateTime()
          ..dateTime = endTime.toUtc()
          ..timeZone = 'Asia/Dushanbe';
        event.end = endEventDateTime;
      }

      await calendarApi.events.update(event, eventId, 'primary');
      return true;
    } catch (e) {
      print('❌ Ошибка обновления события: $e');
      return false;
    } finally {
      client.close();
    }
  }

  // Удалить событие
  static Future<bool> deleteEvent(String eventId) async {
    final client = await getAuthenticatedClient();
    if (client == null) return false;

    final calendarApi = CalendarApi(client);
    try {
      await calendarApi.events.delete(eventId, 'primary');
      return true;
    } catch (e) {
      print('❌ Ошибка удаления события: $e');
      return false;
    } finally {
      client.close();
    }
  }

  // Сохраняем Google аккаунт в Supabase (чтобы помнить, что мастер подключил)
  static Future<void> saveGoogleAccountToSupabase(
      String userId, GoogleSignInAccount account) async {
    try {
      await Supabase.instance.client.from('master_integrations').upsert({
        'master_id': userId,
        'google_email': account.email,
        'google_display_name': account.displayName,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Ошибка сохранения Google аккаунта: $e');
    }
  }

  // Получить сохранённый Google аккаунт из Supabase
  static Future<Map<String, dynamic>?> getGoogleAccountFromSupabase(
      String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('master_integrations')
          .select('google_email, google_display_name')
          .eq('master_id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('❌ Ошибка получения Google аккаунта: $e');
      return null;
    }
  }
}
