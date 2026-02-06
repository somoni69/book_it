import 'package:equatable/equatable.dart';
import '../../domain/entities/time_slot.dart';

abstract class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object> get props => [];
}

class LoadBookingsForDate extends BookingEvent {
  final DateTime date;
  final int serviceDuration;
  final String serviceId;

  const LoadBookingsForDate(this.date, this.serviceDuration, this.serviceId);

  @override
  List<Object> get props => [date, serviceDuration, serviceId];
}

class SelectTimeSlot extends BookingEvent {
  final TimeSlot slot;
  const SelectTimeSlot(this.slot);
  @override
  List<Object> get props => [slot];
}

class ConfirmBooking extends BookingEvent {
  final String serviceId;

  const ConfirmBooking(this.serviceId);

  @override
  List<Object> get props => [serviceId];
}

class CancelBookingEvent extends BookingEvent {
  final String bookingId;
  const CancelBookingEvent(this.bookingId);

  @override
  List<Object> get props => [bookingId];
}
