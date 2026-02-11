part of 'reminders_bloc.dart';

abstract class RemindersEvent extends Equatable {
  const RemindersEvent();

  @override
  List<Object> get props => [];
}

class LoadReminders extends RemindersEvent {
  final String masterId;
  const LoadReminders(this.masterId);
}

class SendReminder extends RemindersEvent {
  final String bookingId;
  final String clientId;
  final String clientName;
  final DateTime bookingTime;
  final String clientFCMToken;
  const SendReminder(
      {required this.bookingId,
      required this.clientId,
      required this.clientName,
      required this.bookingTime,
      required this.clientFCMToken});
}

class SendBulkReminders extends RemindersEvent {
  final List<String> bookingIds;
  const SendBulkReminders(this.bookingIds);
}

class UpdateReminderStatus extends RemindersEvent {
  final String bookingId;
  final ReminderStatus status;
  const UpdateReminderStatus(this.bookingId, this.status);
}
