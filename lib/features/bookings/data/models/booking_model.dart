import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/booking_entity.dart';

// Указываем, что этот файл состоит из частей, которые сгенерирует скрипт
part 'booking_model.freezed.dart';
part 'booking_model.g.dart';

@freezed
class BookingModel with _$BookingModel {
  // Нам нужен кастомный конструктор и методы, поэтому добавляем ._()
  const BookingModel._();

  // Описываем поля точно так, как они приходят из Supabase (snake_case превращаем в camelCase)
  // @JsonKey(name: 'field_name') помогает мапить sql_names в dartNames
  const factory BookingModel({
    required String id,
    @JsonKey(name: 'master_id') required String masterId,
    @JsonKey(name: 'client_id') required String clientId,
    @JsonKey(name: 'organization_id') required String organizationId,
    @JsonKey(name: 'service_id')
    String? serviceId, // Может быть null в БД, но в коде мы хотим String?

    @JsonKey(name: 'start_time') required DateTime startTime,
    @JsonKey(name: 'end_time') required DateTime endTime,

    @Default('pending')
    String status, // Supabase вернет строку, мапим в enum позже
    String? comment,
    // В Supabase это приходит как map: "profiles": {"full_name": "Иван"}
    @JsonKey(name: 'client_profile') Map<String, dynamic>? clientProfile,
  }) = _BookingModel;

  // Метод для создания из JSON
  factory BookingModel.fromJson(Map<String, dynamic> json) =>
      _$BookingModelFromJson(json);

  // Маппер: Превращаем "Грязную" Модель БД в "Чистую" Entity Домена
  BookingEntity toEntity() {
    // Достаем имя или ставим заглушку
    final clientName = clientProfile?['full_name'] as String? ?? 'Аноним';

    return BookingEntity(
      id: id,
      masterId: masterId,
      clientId: clientId,
      serviceId: serviceId,
      startTime: startTime,
      endTime: endTime,
      // Конвертируем строку из БД в Enum
      status: BookingStatus.values.firstWhere(
        (e) => e.name == status,
        orElse: () => BookingStatus.pending,
      ),
      comment: comment,
      clientName: clientName, // <--- Нужно добавить это поле в BookingEntity!
    );
  }
}
