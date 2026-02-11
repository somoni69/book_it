part of 'create_booking_bloc.dart';

abstract class CreateBookingState extends Equatable {
  const CreateBookingState();

  @override
  List<Object> get props => [];
}

class CreateBookingInitial extends CreateBookingState {}

class CreateBookingLoading extends CreateBookingState {}

class CreateBookingDataLoaded extends CreateBookingState {
  final List<Map<String, dynamic>> clients;
  final List<Map<String, dynamic>> services;
  final String? selectedClientId;
  final String? selectedServiceId;
  final String? selectedClientName;
  final String? selectedServiceName;
  final int? selectedServiceDuration;
  final int? selectedServicePrice;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final String? comment;
  final List<DateTime> busySlots;

  const CreateBookingDataLoaded({
    required this.clients,
    required this.services,
    this.selectedClientId,
    this.selectedServiceId,
    this.selectedClientName,
    this.selectedServiceName,
    this.selectedServiceDuration,
    this.selectedServicePrice,
    this.selectedDate,
    this.selectedTime,
    this.comment = '',
    this.busySlots = const [],
  });

  CreateBookingDataLoaded copyWith({
    List<Map<String, dynamic>>? clients,
    List<Map<String, dynamic>>? services,
    String? selectedClientId,
    String? selectedServiceId,
    String? selectedClientName,
    String? selectedServiceName,
    int? selectedServiceDuration,
    int? selectedServicePrice,
    DateTime? selectedDate,
    TimeOfDay? selectedTime,
    String? comment,
    List<DateTime>? busySlots,
  }) {
    return CreateBookingDataLoaded(
      clients: clients ?? this.clients,
      services: services ?? this.services,
      selectedClientId: selectedClientId ?? this.selectedClientId,
      selectedServiceId: selectedServiceId ?? this.selectedServiceId,
      selectedClientName: selectedClientName ?? this.selectedClientName,
      selectedServiceName: selectedServiceName ?? this.selectedServiceName,
      selectedServiceDuration:
          selectedServiceDuration ?? this.selectedServiceDuration,
      selectedServicePrice: selectedServicePrice ?? this.selectedServicePrice,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime: selectedTime ?? this.selectedTime,
      comment: comment ?? this.comment,
      busySlots: busySlots ?? this.busySlots,
    );
  }

  bool get canSubmit {
    return selectedClientId != null &&
        selectedServiceId != null &&
        selectedDate != null &&
        selectedTime != null;
  }

  DateTime? get calculatedEndTime {
    if (selectedDate == null ||
        selectedTime == null ||
        selectedServiceDuration == null) {
      return null;
    }
    final startDateTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );
    return startDateTime.add(Duration(minutes: selectedServiceDuration!));
  }

  @override
  List<Object> get props => [
        clients,
        services,
        selectedClientId ?? '',
        selectedServiceId ?? '',
        selectedClientName ?? '',
        selectedServiceName ?? '',
        selectedServiceDuration ?? 0,
        selectedServicePrice ?? 0,
        selectedDate ?? DateTime(2000),
        selectedTime ?? const TimeOfDay(hour: 0, minute: 0),
        comment ?? '',
        busySlots,
      ];
}

class CreateBookingSuccess extends CreateBookingState {
  final String bookingId;
  const CreateBookingSuccess(this.bookingId);
}

class CreateBookingError extends CreateBookingState {
  final String message;
  const CreateBookingError(this.message);
}
