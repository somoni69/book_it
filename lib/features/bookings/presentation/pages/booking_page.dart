import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Импорты слоев
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../data/repositories/service_repository_impl.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import '../../domain/entities/service_entity.dart';

class BookingPageWrapper extends StatelessWidget {
  final ServiceEntity service;

  const BookingPageWrapper({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final dataSource = BookingRemoteDataSourceImpl(supabase);
    final repository = BookingRepositoryImpl(dataSource);
    final serviceRepository = ServiceRepositoryImpl(supabase);

    return BlocProvider(
      create: (context) => BookingBloc(
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
      child: BookingPage(service: service),
    );
  }
}

class BookingPage extends StatefulWidget {
  final ServiceEntity service;
  const BookingPage({super.key, required this.service});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is BookingLoaded) {
          if (state.submissionStatus == BookingSubmissionStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("✅ Запись успешно создана!"),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state.submissionStatus ==
              BookingSubmissionStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("❌ Ошибка при записи"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Запись: ${widget.service.title}"),
          actions: [
            IconButton(
              icon: const Icon(Icons.exit_to_app, color: Colors.red),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // КАЛЕНДАРЬ
            TableCalendar(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              currentDay: DateTime.now(),
              startingDayOfWeek: StartingDayOfWeek.monday,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });

                  context.read<BookingBloc>().add(
                        LoadBookingsForDate(
                          selectedDay,
                          widget.service.durationMin,
                          widget.service.id,
                        ),
                      );
                }
              },
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
              ),
            ),

            const Divider(),

            // СПИСОК БРОНЕЙ (Или слотов)
            Expanded(
              child: BlocBuilder<BookingBloc, BookingState>(
                builder: (context, state) {
                  if (state is BookingLoading) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (state is BookingError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  } else if (state is BookingLoaded) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Заголовок
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            "Доступное время",
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),

                        // СЕТКА СЛОТОВ
                        Expanded(
                          child: state.slots.isEmpty
                              ? const Center(
                                  child: Text("Нет свободных мест 😔"),
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4, // 4 слота в ряд
                                    childAspectRatio: 2.2, // Пропорция кнопки
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                  ),
                                  itemCount: state.slots.length,
                                  itemBuilder: (context, index) {
                                    final slot = state.slots[index];
                                    final isSelected =
                                        state.selectedSlot == slot;

                                    return GestureDetector(
                                      onTap: slot.isAvailable
                                          ? () => context
                                              .read<BookingBloc>()
                                              .add(SelectTimeSlot(slot))
                                          : null,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        decoration: BoxDecoration(
                                          // Цвет: Выбран ? Синий : (Свободен ? Белый : Серый)
                                          color: isSelected
                                              ? Colors.blueAccent
                                              : (slot.isAvailable
                                                  ? Colors.white
                                                  : Colors.grey[100]),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            // Обводка: Выбран ? Синяя : (Свободен ? Серая : Прозрачная)
                                            color: isSelected
                                                ? Colors.blueAccent
                                                : (slot.isAvailable
                                                    ? Colors.grey.shade300
                                                    : Colors.transparent),
                                            width: 1.5,
                                          ),
                                          boxShadow: slot.isAvailable &&
                                                  !isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.grey
                                                        .withValues(alpha: 0.1),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Center(
                                          child: Text(
                                            _formatTime(slot.startTime),
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : (slot.isAvailable
                                                      ? Colors.black87
                                                      : Colors.grey[400]),
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              decoration: !slot.isAvailable
                                                  ? TextDecoration.lineThrough
                                                  : null, // Зачеркнуть занятые
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // КНОПКА ПОДТВЕРЖДЕНИЯ (Показываем только если выбран слот)
                        if (state.selectedSlot != null)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: const Offset(0, -5),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.black, // Стильный черный цвет
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: state.submissionStatus ==
                                        BookingSubmissionStatus.submitting
                                    ? null // Блокируем кнопку пока грузится
                                    : () {
                                        context.read<BookingBloc>().add(
                                              ConfirmBooking(widget.service.id),
                                            );
                                      },
                                child: state.submissionStatus ==
                                        BookingSubmissionStatus.submitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        "Подтвердить запись",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
        // Кнопка добавления (пока заглушка)
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Скоро тут будет создание записи!")),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
