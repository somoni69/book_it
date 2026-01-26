import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import 'masters_list_page.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = BookingRepositoryImpl(BookingRemoteDataSourceImpl(Supabase.instance.client));

    return Scaffold(
      appBar: AppBar(
        title: const Text("BookIt: Сервисы"),
        actions: [IconButton(icon: const Icon(Icons.exit_to_app), onPressed: () => Supabase.instance.client.auth.signOut())],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repo.getCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final categories = snapshot.data ?? [];
          if (categories.isEmpty) return const Center(child: Text("Нет категорий"));

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 колонки
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return _buildCategoryCard(context, cat);
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, dynamic> category) {
    // Маппинг иконок (текст из базы -> иконка Flutter)
    IconData iconData;
    switch (category['icon']) {
      case 'medical_services': iconData = Icons.medical_services; break;
      case 'face': iconData = Icons.face; break;
      case 'fitness_center': iconData = Icons.fitness_center; break;
      default: iconData = Icons.category;
    }

    return GestureDetector(
      onTap: () {
        // Переходим к списку мастеров, но передаем ID категории!
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MastersListPage(categoryId: category['id']),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blueAccent.withOpacity(0.1),
              child: Icon(iconData, size: 30, color: Colors.blueAccent),
            ),
            const SizedBox(height: 12),
            Text(
              category['name'],
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
