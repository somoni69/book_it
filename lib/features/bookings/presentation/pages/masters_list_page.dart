import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import 'service_selection_page.dart';

class MastersListPage extends StatelessWidget {
  final String categoryId;
  const MastersListPage({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    // Инициализация репо
    final repo = BookingRepositoryImpl(
      BookingRemoteDataSourceImpl(Supabase.instance.client),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Выберите мастера"),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.getMastersByCategory(categoryId), // Грузим мастеров
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final masters = snapshot.data ?? [];
          if (masters.isEmpty) {
            return const Center(child: Text("Мастеров пока нет 🤷‍♂️"));
          }

          return ListView.builder(
            itemCount: masters.length,
            itemBuilder: (context, index) {
              final master = masters[index];
              final fullName = master['full_name'] ?? 'Без имени';
              final firstLetter = fullName.isNotEmpty ? fullName[0] : '?';

              return ListTile(
                leading: CircleAvatar(child: Text(firstLetter)),
                title: Text(fullName),
                subtitle: const Text("Топ барбер"),
                onTap: () {
                  // ВОТ ОНО! ПЕРЕДАЕМ ID МАСТЕРА ДИНАМИЧЕСКИ!
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ServiceSelectionPage(masterId: master['id']),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
