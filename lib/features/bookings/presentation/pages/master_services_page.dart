import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MasterServicesPage extends StatefulWidget {
  const MasterServicesPage({super.key});

  @override
  State<MasterServicesPage> createState() => _MasterServicesPageState();
}

class _MasterServicesPageState extends State<MasterServicesPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    final userId = _supabase.auth.currentUser!.id;
    final data = await _supabase.from('services').select().eq('master_id', userId);
    setState(() {
      _services = List<Map<String, dynamic>>.from(data);
      _isLoading = false;
    });
  }

  Future<void> _addOrEditService({Map<String, dynamic>? service}) async {
    final titleController = TextEditingController(text: service?['title']);
    final priceController = TextEditingController(text: service != null ? service['price'].toString() : '');
    final durationController = TextEditingController(text: service != null ? service['duration_min'].toString() : '60');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(service == null ? "Новая услуга" : "Редактировать"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Название (напр. Стрижка)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Цена (Сомони)", suffixText: "с.", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Длительность (мин)", suffixText: "мин.", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);

              final userId = _supabase.auth.currentUser!.id;
              const orgId = 'd5d6cd49-d1d4-4372-971f-1d497bdb6c0e'; 

              final data = {
                'master_id': userId,
                'organization_id': orgId,
                'title': titleController.text,
                'price': double.tryParse(priceController.text) ?? 0,
                'duration_min': int.tryParse(durationController.text) ?? 60,
              };

              if (service == null) {
                await _supabase.from('services').insert(data);
              } else {
                await _supabase.from('services').update(data).eq('id', service['id']);
              }
              _loadServices();
            },
            child: const Text("Сохранить"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Мои услуги и Цены")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
              ? const Center(child: Text("Добавьте вашу первую услугу!"))
              : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _services.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final s = _services[index];
                      return Card(
                        child: ListTile(
                          title: Text(s['title'], style: const TextStyle(fontWeight: FontWeight.bold)), 
                          subtitle: Text("${s['duration_min']} мин"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               Text("${s['price']} с.", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _addOrEditService(service: s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await _supabase.from('services').delete().eq('id', s['id']);
                                _loadServices();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditService(),
        label: const Text("Добавить услугу"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
    );
  }
}