import 'package:equatable/equatable.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/time_slot.dart';

abstract class BookingState extends Equatable {
  const BookingState();

  @override
  List<Object?> get props => [];
}

class BookingInitial extends BookingState {}

class BookingLoading extends BookingState {}

enum BookingSubmissionStatus { idle, submitting, success, failure }

class BookingLoaded extends BookingState {
  final List<BookingEntity> bookings;
  final List<TimeSlot> slots;
  final DateTime selectedDate;
  final TimeSlot? selectedSlot; // <--- Выбранный слот (может быть null)
  final BookingSubmissionStatus submissionStatus; // <--- НОВОЕ

  const BookingLoaded({
    required this.bookings,
    required this.slots,
    required this.selectedDate,
    this.selectedSlot,
    this.submissionStatus = BookingSubmissionStatus.idle, // Default
  });

  // CopyWith нужен, чтобы удобнее обновлять стейт без пересоздания всего
  BookingLoaded copyWith({
    List<BookingEntity>? bookings,
    List<TimeSlot>? slots,
    DateTime? selectedDate,
    TimeSlot? selectedSlot,
    BookingSubmissionStatus? submissionStatus,
  }) {
    return BookingLoaded(
      bookings: bookings ?? this.bookings,
      slots: slots ?? this.slots,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedSlot: selectedSlot ?? this.selectedSlot,
      submissionStatus: submissionStatus ?? this.submissionStatus,
    );
  }

  @override
  List<Object?> get props => [
    bookings,
    slots,
    selectedDate,
    selectedSlot,
    submissionStatus,
  ];
}

class BookingError extends BookingState {
  final String message;

  const BookingError(this.message);

  @override
  List<Object> get props => [message];
}
