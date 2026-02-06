import '../entities/service_entity.dart';

abstract class ServiceRepository {
  /// Получить все услуги мастера
  Future<List<ServiceEntity>> getServicesByMaster(String masterId);

  /// Создать новую услугу
  Future<ServiceEntity> createService(ServiceEntity service);

  /// Обновить услугу
  Future<ServiceEntity> updateService(ServiceEntity service);

  /// Удалить услугу
  Future<void> deleteService(String serviceId);
}
