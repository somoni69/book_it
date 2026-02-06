import '../entities/working_hour_entity.dart';
import '../repositories/working_hour_repository.dart';

class GetMasterWorkingHours {
  final WorkingHourRepository _repository;

  GetMasterWorkingHours(this._repository);

  Future<List<WorkingHourEntity>> call(String masterId) async {
    return await _repository.getWorkingHours(masterId);
  }
}
