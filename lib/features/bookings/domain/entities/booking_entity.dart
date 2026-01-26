import 'package:equatable/equatable.dart';

enum BookingStatus { pending, confirmed, cancelled, completed }

class BookingEntity extends Equatable {
  final String id;
  final String masterId;
  final String clientId;
  final String? serviceId;
  final DateTime startTime;
  final DateTime endTime;
  final BookingStatus status;
  final String? comment;
  final String clientName; // <--- Новое поле

  const BookingEntity({
    required this.id,
    required this.masterId,
    required this.clientId,
    this.serviceId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.comment,
    this.clientName = 'Аноним', // Добавим дефолт
  });

  @override
  List<Object?> get props => [id, masterId, startTime, status, clientName];

  // Хелпер: закончилась ли запись?
  bool get isPast => DateTime.now().isAfter(endTime);
}
