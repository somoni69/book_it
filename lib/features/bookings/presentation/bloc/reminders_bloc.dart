import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:equatable/equatable.dart';

part 'reminders_event.dart';
part 'reminders_state.dart';

class RemindersBloc extends Bloc<RemindersEvent, RemindersState> {
  final SupabaseClient supabase;
  Timer? _autoRefreshTimer;

  RemindersBloc({required this.supabase}) : super(RemindersInitial()) {
    on<LoadReminders>(_onLoadReminders);
    on<SendReminder>(_onSendReminder);
    on<SendBulkReminders>(_onSendBulkReminders);
    on<UpdateReminderStatus>(_onUpdateReminderStatus);

    // Автообновление каждые 5 минут
    _startAutoRefresh();
  }

  @override
  Future<void> close() {
    _autoRefreshTimer?.cancel();
    return super.close();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      final currentState = state;
      if (currentState is RemindersLoaded) {
        // Перезагружаем данные
        add(LoadReminders(_getCurrentMasterId()));
      }
    });
  }

  String _getCurrentMasterId() {
    return supabase.auth.currentUser?.id ?? '';
  }

  Future<void> _onLoadReminders(
    LoadReminders event,
    Emitter<RemindersState> emit,
  ) async {
    emit(RemindersLoading());

    try {
      final masterId = event.masterId;
      final now = DateTime.now();
      final sevenDaysLater = now.add(const Duration(days: 7));

      // Загружаем предстоящие записи
      final response = await supabase
          .from('bookings')
          .select('''
            id,
            start_time,
            end_time,
            status,
            comment,
            client_id,
            service_id,
            client_profile:profiles!bookings_client_id_fkey(full_name, avatar_url),
            service:services(name, duration_minutes),
            fcm_token:user_fcm_tokens(fcm_token)
          ''')
          .eq('master_id', masterId)
          .gte('start_time', now.toIso8601String())
          .lte('start_time', sevenDaysLater.toIso8601String())
          .or('status.eq.pending,status.eq.confirmed')
          .order('start_time', ascending: true);

      final bookings = (response as List).map((booking) {
        final clientProfile = booking['client_profile'] ?? {};
        final service = booking['service'] ?? {};
        final fcmTokens = booking['fcm_token'] as List?;

        return {
          'id': booking['id'] as String,
          'start_time': DateTime.parse(booking['start_time'] as String),
          'end_time': DateTime.parse(booking['end_time'] as String),
          'client_id': booking['client_id'] as String,
          'client_name': clientProfile['full_name'] as String? ?? 'Клиент',
          'client_avatar': clientProfile['avatar_url'] as String?,
          'service_name': service['name'] as String? ?? 'Услуга',
          'duration': service['duration_minutes'] as int? ?? 60,
          'comment': booking['comment'] as String?,
          'status': booking['status'] as String,
          'fcm_token': fcmTokens?.isNotEmpty == true
              ? fcmTokens!.first['fcm_token'] as String?
              : null,
        };
      }).toList();

      // Загружаем предыдущие статусы напоминаний из локального хранилища
      final Map<String, ReminderStatus> statuses = {};
      for (final booking in bookings) {
        statuses[booking['id'] as String] = ReminderStatus.pending;
      }

      emit(RemindersLoaded(
        upcomingBookings: bookings,
        reminderStatuses: statuses,
      ));
    } catch (e) {
      emit(RemindersError('Ошибка загрузки записей: $e'));
    }
  }

  Future<void> _onSendReminder(
    SendReminder event,
    Emitter<RemindersState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RemindersLoaded) return;

    // Обновляем статус на "отправляется"
    final updatedStatuses = Map<String, ReminderStatus>.from(
      currentState.reminderStatuses,
    );
    updatedStatuses[event.bookingId] = ReminderStatus.sending;
    emit(currentState.copyWith(reminderStatuses: updatedStatuses));

    try {
      // Реальная отправка через Supabase Function
      final response =
          await supabase.functions.invoke('send-push-notification', body: {
        'booking_id': event.bookingId,
        'client_id': event.clientId,
        'title': 'Напоминание о записи',
        'body': '${event.clientName}, ваша запись через 1 час',
        'data': {
          'type': 'reminder',
          'time': event.bookingTime.toIso8601String(),
        },
      });

      if (response.status == 200) {
        updatedStatuses[event.bookingId] = ReminderStatus.sent;
        final newSentCount = currentState.sentCount + 1;
        emit(currentState.copyWith(
          reminderStatuses: updatedStatuses,
          sentCount: newSentCount,
        ));
      } else {
        throw Exception('Failed to send notification');
      }

      await _logReminderSent(event.bookingId, event.clientName);
    } catch (e) {
      // Обновляем статус на "ошибка"
      updatedStatuses[event.bookingId] = ReminderStatus.failed;
      emit(currentState.copyWith(reminderStatuses: updatedStatuses));
    }
  }

  Future<void> _onSendBulkReminders(
    SendBulkReminders event,
    Emitter<RemindersState> emit,
  ) async {
    final currentState = state;
    if (currentState is! RemindersLoaded) return;

    emit(currentState.copyWith(isSending: true));

    try {
      // Ищем записи для отправки
      for (final bookingId in event.bookingIds) {
        final booking = currentState.upcomingBookings.firstWhere(
          (b) => b['id'] == bookingId,
        );

        // Отправляем каждое напоминание
        add(SendReminder(
          bookingId: bookingId,
          clientId: booking['client_id'] as String,
          clientName: booking['client_name'] as String,
          bookingTime: booking['start_time'] as DateTime,
          clientFCMToken: booking['fcm_token'] as String? ?? '',
        ));

        // Небольшая задержка между отправками
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      emit(RemindersError('Ошибка массовой отправки: $e'));
    } finally {
      if (state is RemindersLoaded) {
        emit((state as RemindersLoaded).copyWith(isSending: false));
      }
    }
  }

  void _onUpdateReminderStatus(
    UpdateReminderStatus event,
    Emitter<RemindersState> emit,
  ) {
    final currentState = state;
    if (currentState is! RemindersLoaded) return;

    final updatedStatuses = Map<String, ReminderStatus>.from(
      currentState.reminderStatuses,
    );
    updatedStatuses[event.bookingId] = event.status;

    emit(currentState.copyWith(reminderStatuses: updatedStatuses));
  }

  Future<void> _logReminderSent(String bookingId, String clientName) async {
    try {
      await supabase.from('reminder_logs').insert({
        'booking_id': bookingId,
        'client_name': clientName,
        'sent_at': DateTime.now().toIso8601String(),
        'type': 'manual',
      });
    } catch (e) {
      print('Ошибка логирования напоминания: $e');
    }
  }
}
