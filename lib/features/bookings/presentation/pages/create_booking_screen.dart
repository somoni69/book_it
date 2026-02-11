import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:book_it/core/services/calendar_service.dart';
import '../../domain/entities/booking_entity.dart';
import '../bloc/create_booking_bloc.dart';

class CreateBookingScreen extends StatefulWidget {
  final String? preSelectedClientId;
  final String? preSelectedServiceId;

  const CreateBookingScreen({
    super.key,
    this.preSelectedClientId,
    this.preSelectedServiceId,
  });

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final _commentController = TextEditingController();
  DateTime? _tempSelectedDate;
  TimeOfDay? _tempSelectedTime;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onCommentChanged);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _onCommentChanged() {
    final text = _commentController.text;
    context.read<CreateBookingBloc>().add(CommentChanged(text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateBookingBloc, CreateBookingState>(
      listener: (context, state) {
        if (state is CreateBookingSuccess) {
          // Показываем успех и предлагаем добавить в календарь
          _showSuccessDialog(context, state.bookingId);
        }
        if (state is CreateBookingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Новая запись'),
            actions: [
              if (state is CreateBookingDataLoaded && state.canSubmit)
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () =>
                      context.read<CreateBookingBloc>().add(SubmitBooking()),
                  tooltip: 'Создать запись',
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    context.read<CreateBookingBloc>().add(ResetForm()),
                tooltip: 'Очистить форму',
              ),
            ],
          ),
          body: _buildBody(state),
        );
      },
    );
  }

  Widget _buildBody(CreateBookingState state) {
    if (state is CreateBookingInitial || state is CreateBookingLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is CreateBookingDataLoaded) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Выбор клиента
            _buildClientSection(state),
            const SizedBox(height: 20),
            // Выбор услуги
            _buildServiceSection(state),
            const SizedBox(height: 20),
            // Выбор даты и времени
            _buildDateTimeSection(state),
            const SizedBox(height: 20),
            // Комментарий
            _buildCommentSection(),
            const SizedBox(height: 20),
            // Предпросмотр записи
            if (state.canSubmit) _buildPreviewSection(state),
            const SizedBox(height: 30),
            // Кнопка создания
            _buildSubmitButton(state),
          ],
        ),
      );
    }

    return const Center(child: Text('Ошибка загрузки данных'));
  }

  Widget _buildClientSection(CreateBookingDataLoaded state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              leading: Icon(Icons.person, color: Colors.blue),
              title:
                  Text('Клиент', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            if (state.selectedClientId != null)
              ListTile(
                title: Text(state.selectedClientName!),
                subtitle: Text('ID: ${state.selectedClientId}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.read<CreateBookingBloc>().add(
                        ClientSelected('', ''),
                      ),
                ),
              )
            else
              ...state.clients.map((client) => ListTile(
                    title: Text(client['name'] as String),
                    subtitle: client['phone'] != null
                        ? Text(client['phone'] as String)
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.read<CreateBookingBloc>().add(
                          ClientSelected(
                            client['id'] as String,
                            client['name'] as String,
                          ),
                        ),
                  )),
            if (state.clients.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Нет доступных клиентов',
                    style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSection(CreateBookingDataLoaded state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              leading: Icon(Icons.content_cut, color: Colors.green),
              title:
                  Text('Услуга', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            if (state.selectedServiceId != null)
              ListTile(
                title: Text(state.selectedServiceName!),
                subtitle: Text(
                  '${state.selectedServiceDuration} мин • ${state.selectedServicePrice} с.',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.read<CreateBookingBloc>().add(
                        ServiceSelected('', '', 0, 0),
                      ),
                ),
              )
            else
              ...state.services.map((service) => ListTile(
                    title: Text(service['name'] as String),
                    subtitle: Text(
                      '${service['duration']} мин • ${service['price']} с.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.read<CreateBookingBloc>().add(
                          ServiceSelected(
                            service['id'] as String,
                            service['name'] as String,
                            service['duration'] as int,
                            service['price'] as int,
                          ),
                        ),
                  )),
            if (state.services.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Нет доступных услуг',
                    style: TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSection(CreateBookingDataLoaded state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              leading: Icon(Icons.calendar_today, color: Colors.orange),
              title: Text('Дата и время',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            // Дата
            ListTile(
              title: const Text('Дата'),
              subtitle: Text(
                state.selectedDate != null
                    ? DateFormat('EEEE, d MMMM y', 'ru')
                        .format(state.selectedDate!)
                    : 'Не выбрана',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _selectDate(context, state),
            ),
            // Время
            if (state.selectedDate != null)
              ListTile(
                title: const Text('Время'),
                subtitle: Text(
                  state.selectedTime != null
                      ? '${state.selectedTime!.hour}:${state.selectedTime!.minute.toString().padLeft(2, '0')}'
                      : 'Не выбрано',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectTime(context, state),
              ),
            // Занятые слоты
            if (state.busySlots.isNotEmpty && state.selectedDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Занятые время: ${state.busySlots.map((t) => DateFormat.Hm().format(t)).join(', ')}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(
      BuildContext context, CreateBookingDataLoaded state) async {
    final now = DateTime.now();
    final firstDate = now.subtract(const Duration(days: 30));
    final lastDate = now.add(const Duration(days: 365));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: state.selectedDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('ru', 'RU'),
    );

    if (pickedDate != null) {
      _tempSelectedDate = pickedDate;
      // Если время уже было выбрано, сразу обновляем состояние
      if (state.selectedTime != null) {
        context.read<CreateBookingBloc>().add(
              DateTimeSelected(pickedDate, state.selectedTime!),
            );
      }
      // Если время не выбрано, предлагаем выбрать его
      else if (mounted) {
        _selectTime(context, state);
      }
    }
  }

  Future<void> _selectTime(
      BuildContext context, CreateBookingDataLoaded state) async {
    final initialTime =
        state.selectedTime ?? const TimeOfDay(hour: 9, minute: 0);

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Localizations.override(
          context: context,
          locale: const Locale('ru', 'RU'),
          child: child,
        );
      },
    );

    if (pickedTime != null) {
      _tempSelectedTime = pickedTime;
      final dateToUse =
          state.selectedDate ?? _tempSelectedDate ?? DateTime.now();
      context.read<CreateBookingBloc>().add(
            DateTimeSelected(dateToUse, pickedTime),
          );
    }
  }

  Widget _buildCommentSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              leading: Icon(Icons.comment, color: Colors.purple),
              title: Text('Комментарий',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Дополнительная информация...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection(CreateBookingDataLoaded state) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Предпросмотр записи:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(state.selectedClientName!)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.content_cut, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(state.selectedServiceName!)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${DateFormat('dd.MM.yyyy').format(state.selectedDate!)} '
                    '${state.selectedTime!.hour}:${state.selectedTime!.minute.toString().padLeft(2, '0')} - '
                    '${state.calculatedEndTime != null ? DateFormat.Hm().format(state.calculatedEndTime!) : ''}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 16),
                const SizedBox(width: 8),
                Text('${state.selectedServicePrice} сомони'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(CreateBookingDataLoaded state) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.add_circle, size: 24),
      label: const Text('СОЗДАТЬ ЗАПИСЬ', style: TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: state.canSubmit
          ? () => context.read<CreateBookingBloc>().add(SubmitBooking())
          : null,
    );
  }

  Future<void> _showSuccessDialog(
      BuildContext context, String bookingId) async {
    final shouldAddToCalendar = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Запись создана! 🎉'),
            content: const Text('Хотите добавить эту запись в свой календарь?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ПОЗЖЕ'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('ДОБАВИТЬ В КАЛЕНДАРЬ',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldAddToCalendar && context.mounted) {
      // TODO: Здесь нужно загрузить полные данные о записи
      // Пока используем заглушку
      final fakeBooking = BookingEntity(
        id: bookingId,
        masterId: 'master_id',
        clientId: 'client_id',
        startTime: DateTime.now().add(const Duration(days: 1)),
        endTime: DateTime.now().add(const Duration(days: 1, hours: 1)),
        status: BookingStatus.confirmed,
        clientName: 'Клиент',
        masterName: 'Мастер',
      );

      final description = CalendarService.instance.buildBookingDescription(
        serviceName: 'Услуга',
        masterName: 'Мастер',
        clientName: 'Клиент',
      );

      final success = await CalendarService.instance.addBookingToCalendar(
        title: 'Запись: Услуга',
        description: description,
        startDate: fakeBooking.startTime,
        endDate: fakeBooking.endTime,
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Добавлено в календарь! 📅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    // Возвращаемся на предыдущий экран
    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}
