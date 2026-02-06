import '../entities/master_stats_entity.dart';

abstract class MasterStatsRepository {
  Future<MasterStatsEntity> getMasterStats(String masterId);
}
