import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/repositories/auth_repository_impl.dart';
import 'master_specialty_page.dart';

class MasterSetupPage extends StatefulWidget {
  const MasterSetupPage({super.key});

  @override
  State<MasterSetupPage> createState() => _MasterSetupPageState();
}

class _MasterSetupPageState extends State<MasterSetupPage> {
  final _repo = AuthRepositoryImpl(Supabase.instance.client);
  final _supabase = Supabase.instance.client;

  // Оставил твои методы нетронутыми, на случай если они используются в другой части флоу
  Future<void> _completeMasterSetup(String specialtyId) async {
    try {
      final userId = await _repo.getCurrentUserId();
      await _repo.updateProfile(profileId: userId, updates: {'role': 'master', 'specialty_id': specialtyId});
      await _createOrganizationForMaster(userId);
      await _createDefaultServices(userId, specialtyId);
      await _createDefaultWorkingHours(userId);
      if (mounted) Navigator.pushReplacementNamed(context, '/master-home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _createOrganizationForMaster(String masterId) async {
    try {
      final profile = await _repo.getProfile(masterId);
      final fullName = profile['full_name'] ?? 'Master';
      final org = await _supabase.from('organizations').insert({'name': '$fullName Studio', 'owner_id': masterId, 'type': 'individual', 'created_at': DateTime.now().toIso8601String()}).select('id').single();
      await _repo.updateProfile(profileId: masterId, updates: {'organization_id': org['id']});
    } catch (e) {
      // Non-blocking
    }
  }

  Future<void> _createDefaultServices(String masterId, String specialtyId) async {
    final services = [{'name': 'Main Service', 'duration_min': 60, 'price': 200.0}];
    for (final service in services) {
      await _supabase.from('services').insert({'master_id': masterId, 'name': service['name'], 'duration_min': service['duration_min'], 'price': service['price'], 'currency': 'TJS', 'is_active': true, 'created_at': DateTime.now().toIso8601String()});
    }
  }

  Future<void> _createDefaultWorkingHours(String masterId) async {
    final workingHours = List.generate(7, (index) {
      final isDayOff = index >= 5;
      return {'master_id': masterId, 'day_of_week': index + 1, 'start_time': '09:00:00', 'end_time': '18:00:00', 'is_day_off': isDayOff, 'is_active': true, 'created_at': DateTime.now().toIso8601String()};
    });
    await _supabase.from('working_hours').insert(workingHours);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Настройка профиля", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _repo.getCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return _buildSkeletonGrid();

          final categories = snapshot.data ?? [];
          
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Выберите вашу сферу', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 8),
                      Text('Это поможет клиентам быстрее найти вас', style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.95,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildCard(categories[index]),
                    childCount: categories.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> cat) {
    IconData icon;
    Color iconColor;
    Color bgColor;

    final name = cat['name'].toString().toLowerCase();
    if (name.contains("здоровье")) {
      icon = Icons.favorite_rounded;
      iconColor = Colors.red.shade500;
      bgColor = Colors.red.shade50;
    } else if (name.contains("красота") || name.contains("бьюти")) {
      icon = Icons.face_retouching_natural_rounded;
      iconColor = Colors.purple.shade500;
      bgColor = Colors.purple.shade50;
    } else {
      icon = Icons.work_outline_rounded;
      iconColor = Colors.blue.shade500;
      bgColor = Colors.blue.shade50;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => MasterSpecialtyPage(categoryId: cat['id'], categoryName: cat['name'])));
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const Spacer(),
                Text(cat['name'], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Выбрать', style: TextStyle(fontSize: 13, color: Colors.blue.shade600, fontWeight: FontWeight.w600)),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Colors.blue.shade600),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: GridView.builder(
        padding: const EdgeInsets.all(16).copyWith(top: 100), // Отступ под заголовок
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.95),
        itemCount: 6,
        itemBuilder: (_, __) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
      ),
    );
  }
}