import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../data/repositories/service_repository_impl.dart';
import '../../domain/entities/service_entity.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import 'book_service_screen.dart';

class ServiceSelectionPage extends StatefulWidget {
  final String masterId; // <--- ПРИНИМАЕМ СНАРУЖИ
  const ServiceSelectionPage({super.key, required this.masterId});

  @override
  State<ServiceSelectionPage> createState() => _ServiceSelectionPageState();
}

class _ServiceSelectionPageState extends State<ServiceSelectionPage> {
  // Простой DI
  // Простой DI
  final _repository = BookingRepositoryImpl(
    BookingRemoteDataSourceImpl(Supabase.instance.client),
  );

  // Хардкод ID удален

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Выберите услугу"),
        actions: [
          // Кнопка выхода (чтобы не застрять)
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: FutureBuilder<List<ServiceEntity>>(
        future: _repository.getServices(widget.masterId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Ошибка: ${snapshot.error}"));
          }

          final services = snapshot.data ?? [];

          if (services.isEmpty) {
            return const Center(child: Text("У мастера нет услуг 😔"));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final service = services[index];
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.content_cut),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  title: Text(
                    service.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${service.durationMin} мин"),
                  trailing: Text(
                    "${service.price.toInt()} ₽",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    // ПЕРЕХОД К КАЛЕНДАРЮ С НОВЫМ ЭКРАНОМ
                    final supabase = Supabase.instance.client;
                    final dataSource = BookingRemoteDataSourceImpl(supabase);
                    final repository = BookingRepositoryImpl(dataSource);
                    final serviceRepository = ServiceRepositoryImpl(supabase);

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider(
                          create: (context) =>
                              BookingBloc(
                                repository: repository,
                                serviceRepository: serviceRepository,
                                masterId: service.masterId,
                              )..add(
                                LoadBookingsForDate(
                                  DateTime.now(),
                                  service.durationMin,
                                  service.id,
                                ),
                              ),
                          child: BookServiceScreen(
                            masterId: service.masterId,
                            serviceId: service.id,
                            serviceName: service.title,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
