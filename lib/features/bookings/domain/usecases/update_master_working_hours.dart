import '../entities/working_hour_entity.dart';
import '../repositories/working_hour_repository.dart';

class UpdateMasterWorkingHours {
  final WorkingHourRepository _repository;

  UpdateMasterWorkingHours(this._repository);

  Future<void> call(List<WorkingHourEntity> workingHours) async {
    return await _repository.updateWorkingHours(workingHours);
  }
}
