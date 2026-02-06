import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  Future<void> _completeMasterSetup(String specialtyId) async {
    try {
      final userId = await _repo.getCurrentUserId();

      await _repo.updateProfile(
        profileId: userId,
        updates: {'role': 'master', 'specialty_id': specialtyId},
      );

      await _createOrganizationForMaster(userId);
      await _createDefaultServices(userId, specialtyId);
      await _createDefaultWorkingHours(userId);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/master-home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createOrganizationForMaster(String masterId) async {
    try {
      final profile = await _repo.getProfile(masterId);
      final fullName = profile['full_name'] ?? 'Master';

      final org = await _supabase
          .from('organizations')
          .insert({
            'name': '$fullName Studio',
            'owner_id': masterId,
            'type': 'individual',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      await _repo.updateProfile(
        profileId: masterId,
        updates: {'organization_id': org['id']},
      );
    } catch (e) {
      // Non-blocking
    }
  }

  Future<void> _createDefaultServices(
    String masterId,
    String specialtyId,
  ) async {
    final services = [
      {'name': 'Main Service', 'duration_minutes': 60, 'price': 200.0},
    ];

    for (final service in services) {
      await _supabase.from('services').insert({
        'master_id': masterId,
        'name': service['name'],
        'duration_minutes': service['duration_minutes'],
        'price': service['price'],
        'currency': 'TJS',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _createDefaultWorkingHours(String masterId) async {
    final workingHours = List.generate(7, (index) {
      final isDayOff = index >= 5;

      return {
        'master_id': masterId,
        'day_of_week': index + 1,
        'start_time': '09:00:00',
        'end_time': '18:00:00',
        'is_day_off': isDayOff,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      };
    });

    await _supabase.from('working_hours').insert(workingHours);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Выберите сферу деятельности")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _repo.getCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data ?? [];

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return _buildCard(cat);
            },
          );
        },
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> cat) {
    // Иконки
    IconData icon;
    if (cat['name'].toString().contains("Здоровье"))
      icon = Icons.local_hospital;
    else if (cat['name'].toString().contains("Красота"))
      icon = Icons.face;
    else
      icon = Icons.work;

    return GestureDetector(
      onTap: () {
        // ИДЕМ НА ШАГ 2: Выбор специальности
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MasterSpecialtyPage(
              categoryId: cat['id'],
              categoryName: cat['name'],
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.black,
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              cat['name'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
