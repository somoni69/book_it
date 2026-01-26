// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BookingModelImpl _$$BookingModelImplFromJson(Map json) => $checkedCreate(
  r'_$BookingModelImpl',
  json,
  ($checkedConvert) {
    final val = _$BookingModelImpl(
      id: $checkedConvert('id', (v) => v as String),
      masterId: $checkedConvert('master_id', (v) => v as String),
      clientId: $checkedConvert('client_id', (v) => v as String),
      organizationId: $checkedConvert('organization_id', (v) => v as String),
      serviceId: $checkedConvert('service_id', (v) => v as String?),
      startTime: $checkedConvert(
        'start_time',
        (v) => DateTime.parse(v as String),
      ),
      endTime: $checkedConvert('end_time', (v) => DateTime.parse(v as String)),
      status: $checkedConvert('status', (v) => v as String? ?? 'pending'),
      comment: $checkedConvert('comment', (v) => v as String?),
      clientProfile: $checkedConvert(
        'client_profile',
        (v) => (v as Map?)?.map((k, e) => MapEntry(k as String, e)),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'masterId': 'master_id',
    'clientId': 'client_id',
    'organizationId': 'organization_id',
    'serviceId': 'service_id',
    'startTime': 'start_time',
    'endTime': 'end_time',
    'clientProfile': 'client_profile',
  },
);

Map<String, dynamic> _$$BookingModelImplToJson(_$BookingModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'master_id': instance.masterId,
      'client_id': instance.clientId,
      'organization_id': instance.organizationId,
      'service_id': instance.serviceId,
      'start_time': instance.startTime.toIso8601String(),
      'end_time': instance.endTime.toIso8601String(),
      'status': instance.status,
      'comment': instance.comment,
      'client_profile': instance.clientProfile,
    };
