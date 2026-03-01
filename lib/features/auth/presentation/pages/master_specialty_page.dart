import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../role_based_home.dart';

class MasterSpecialtyPage extends StatelessWidget {
  final String categoryId;
  final String categoryName;

  const MasterSpecialtyPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  Future<void> _saveSpecialtyAndProceed(
      BuildContext context, String specialtyId, AuthRepositoryImpl repo) async {
    // Красивый лоадер
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Настраиваем профиль...',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // ИСПРАВЛЕНИЕ: Вызываем полную настройку профиля со всеми дефолтными данными
      await repo.completeMasterSetup(specialtyId);

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const RoleBasedHome()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Закрываем лоадер
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка настройки: $e'),
              backgroundColor: Colors.red.shade600),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = AuthRepositoryImpl(Supabase.instance.client);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(categoryName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.getSpecialtiesByCategory(categoryId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return _buildSkeletonList();

          final specialties = snapshot.data ?? [];

          if (specialties.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("Специальности не найдены",
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: specialties.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final spec = specialties[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        _saveSpecialtyAndProceed(context, spec['id'], repo),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.check_circle_outline_rounded,
                                color: Colors.blue.shade600, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(spec['name'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87)),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 16, color: Colors.grey.shade300),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
            height: 72,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16))),
      ),
    );
  }
}
