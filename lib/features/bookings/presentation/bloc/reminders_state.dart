part of 'reminders_bloc.dart';

// Статус напоминания для отдельной записи
enum ReminderStatus {
  pending,    // Требует напоминания
  sending,    // Отправляется
  sent,       // Успешно отправлено
  failed,     // Ошибка отправки
}

abstract class RemindersState extends Equatable {
  const RemindersState();

  @override
  List<Object> get props => [];
}

class RemindersInitial extends RemindersState {}

class RemindersLoading extends RemindersState {}

class RemindersLoaded extends RemindersState {
  final List<Map<String, dynamic>> upcomingBookings;
  final Map<String, ReminderStatus> reminderStatuses;
  final bool isSending;
  final int sentCount;

  const RemindersLoaded({
    required this.upcomingBookings,
    this.reminderStatuses = const {},
    this.isSending = false,
    this.sentCount = 0,
  });

  // Копирование состояния с обновленными полями
  RemindersLoaded copyWith({
    List<Map<String, dynamic>>? upcomingBookings,
    Map<String, ReminderStatus>? reminderStatuses,
    bool? isSending,
    int? sentCount,
  }) {
    return RemindersLoaded(
      upcomingBookings: upcomingBookings ?? this.upcomingBookings,
      reminderStatuses: reminderStatuses ?? this.reminderStatuses,
      isSending: isSending ?? this.isSending,
      sentCount: sentCount ?? this.sentCount,
    );
  }

  // Получение записей, требующих напоминания (за ближайшие 24 часа)
  List<Map<String, dynamic>> get bookingsNeedingReminder {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    return upcomingBookings.where((booking) {
      final bookingTime = booking['start_time'] as DateTime;
      final isUpcoming = bookingTime.isAfter(now) && bookingTime.isBefore(tomorrow);
      final status = reminderStatuses[booking['id']] ?? ReminderStatus.pending;
      return isUpcoming && status != ReminderStatus.sent;
    }).toList();
  }

  @override
  List<Object> get props => [
    upcomingBookings,
    reminderStatuses,
    isSending,
    sentCount,
  ];
}

class RemindersError extends RemindersState {
  final String message;
  const RemindersError(this.message);

  @override
  List<Object> get props => [message];
}