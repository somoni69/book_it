import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository_impl.dart';
import 'master_specialty_page.dart'; // <--- Сейчас создадим

class MasterSetupPage extends StatefulWidget {
  const MasterSetupPage({super.key});

  @override
  State<MasterSetupPage> createState() => _MasterSetupPageState();
}

class _MasterSetupPageState extends State<MasterSetupPage> {
  final _repo = AuthRepositoryImpl(Supabase.instance.client);
  
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
    if (cat['name'].toString().contains("Здоровье")) icon = Icons.local_hospital;
    else if (cat['name'].toString().contains("Красота")) icon = Icons.face;
    else icon = Icons.work;

    return GestureDetector(
      onTap: () {
        // ИДЕМ НА ШАГ 2: Выбор специальности
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (_) => MasterSpecialtyPage(
              categoryId: cat['id'], 
              categoryName: cat['name']
            )
          )
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
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
