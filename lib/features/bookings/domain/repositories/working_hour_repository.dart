import '../entities/working_hour_entity.dart';

abstract class WorkingHourRepository {
  /// Получить рабочий график мастера
  Future<List<WorkingHourEntity>> getWorkingHours(String masterId);

  /// Обновить/создать рабочий график
  Future<void> updateWorkingHours(List<WorkingHourEntity> workingHours);

  /// Удалить рабочий график
  Future<void> deleteWorkingHour(String id);
}
