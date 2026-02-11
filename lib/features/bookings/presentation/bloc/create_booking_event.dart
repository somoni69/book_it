part of 'create_booking_bloc.dart';

abstract class CreateBookingEvent extends Equatable {
  const CreateBookingEvent();

  @override
  List<Object> get props => [];
}

class LoadInitialData extends CreateBookingEvent {
  final String masterId;
  const LoadInitialData(this.masterId);
}

class ClientSelected extends CreateBookingEvent {
  final String clientId;
  final String clientName;
  const ClientSelected(this.clientId, this.clientName);
}

class ServiceSelected extends CreateBookingEvent {
  final String serviceId;
  final String serviceName;
  final int duration;
  final int price;
  const ServiceSelected(this.serviceId, this.serviceName, this.duration, this.price);
}

class DateTimeSelected extends CreateBookingEvent {
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  const DateTimeSelected(this.selectedDate, this.selectedTime);
}

class CommentChanged extends CreateBookingEvent {
  final String comment;
  const CommentChanged(this.comment);
}

class SubmitBooking extends CreateBookingEvent {
  const SubmitBooking();
}

class ResetForm extends CreateBookingEvent {
  const ResetForm();
}