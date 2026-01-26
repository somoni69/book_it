import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  Widget build(BuildContext context) {
    final repo = AuthRepositoryImpl(Supabase.instance.client);

    return Scaffold(
      appBar: AppBar(title: Text("Выбор: $categoryName")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.getSpecialtiesByCategory(
          categoryId,
        ), // <--- Грузим подкатегории
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final specialties = snapshot.data ?? [];
          if (specialties.isEmpty) {
            return const Center(child: Text("Тут пока пусто 🤷‍♂️"));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: specialties.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final spec = specialties[index];
              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                leading: const Icon(Icons.check_circle_outline),
                title: Text(
                  spec['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () async {
                  showDialog(
                    context: context,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  // 1. Сохраняем специальность в базу
                  await repo.updateMasterSpecialty(spec['id']);

                  if (context.mounted) {
                    // 2. Вместо push на страницу, мы возвращаемся на самый верх (в main.dart)
                    // Это заставит RoleBasedHome перестроиться заново
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const RoleBasedHome(),
                      ), // <--- ИДЕМ В КОРЕНЬ
                      (route) => false,
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
