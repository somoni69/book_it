import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/reminders_bloc.dart';

class RemindersManagementScreen extends StatefulWidget {
  final String masterId;
  const RemindersManagementScreen({super.key, required this.masterId});

  @override
  State<RemindersManagementScreen> createState() =>
      _RemindersManagementScreenState();
}

class _RemindersManagementScreenState extends State<RemindersManagementScreen> {
  final Set<String> _selectedBookings = {};
  bool _selectMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RemindersBloc>().add(LoadReminders(widget.masterId));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: BlocConsumer<RemindersBloc, RemindersState>(
        listener: (context, state) {
          // Обработка ошибок
          if (state is RemindersError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is RemindersInitial || state is RemindersLoading) {
            return _buildLoadingState();
          }

          if (state is RemindersError) {
            return _buildErrorState(context, state);
          }

          if (state is RemindersLoaded) {
            return _buildLoadedState(context, state);
          }

          return const Center(child: Text('Неизвестное состояние'));
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Управление напоминаниями'),
      actions: [
        BlocBuilder<RemindersBloc, RemindersState>(
          builder: (context, state) {
            if (state is! RemindersLoaded) return const SizedBox();

            final needsReminder = state.bookingsNeedingReminder;
            if (needsReminder.isEmpty) return const SizedBox();

            return IconButton(
              icon: const Icon(Icons.send),
              tooltip: 'Отправить все напоминания',
              onPressed: state.isSending
                  ? null
                  : () {
                      final bookingIds =
                          needsReminder.map((b) => b['id'] as String).toList();
                      context.read<RemindersBloc>().add(
                            SendBulkReminders(bookingIds),
                          );
                    },
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Обновить',
          onPressed: () {
            context.read<RemindersBloc>().add(LoadReminders(widget.masterId));
          },
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Загружаем записи...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, RemindersError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.read<RemindersBloc>().add(LoadReminders(widget.masterId));
            },
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, RemindersLoaded state) {
    final bookings = state.bookingsNeedingReminder;

    if (bookings.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        // Статистика
        _buildStatsCard(state),
        const SizedBox(height: 16),

        // Список записей
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              return _buildBookingCard(context, bookings[index], state);
            },
          ),
        ),

        // Кнопка массовой отправки (если выбраны записи)
        if (_selectMode && _selectedBookings.isNotEmpty)
          _buildBottomActionBar(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_off, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Нет записей для напоминаний',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Записи, требующие напоминания, появятся здесь за 24 часа до начала',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить'),
            onPressed: () {
              context.read<RemindersBloc>().add(LoadReminders(widget.masterId));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(RemindersLoaded state) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.access_time,
                  value: '${state.bookingsNeedingReminder.length}',
                  label: 'Требуют напоминания',
                  color: Colors.orange,
                ),
                _buildStatItem(
                  icon: Icons.check_circle,
                  value: '${state.sentCount}',
                  label: 'Отправлено',
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: state.sentCount / state.bookingsNeedingReminder.length,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildBookingCard(
    BuildContext context,
    Map<String, dynamic> booking,
    RemindersLoaded state,
  ) {
    final bookingId = booking['id'] as String;
    final status = state.reminderStatuses[bookingId] ?? ReminderStatus.pending;
    final isSelected = _selectedBookings.contains(bookingId);
    final hasFcmToken = booking['fcm_token'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: _buildLeadingSection(booking, status, isSelected),
        title: Text(
          booking['client_name'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, d MMMM, HH:mm', 'ru').format(
                booking['start_time'] as DateTime,
              ),
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              booking['service_name'] as String,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (!hasFcmToken)
              Text(
                'У клиента нет FCM токена',
                style: TextStyle(fontSize: 11, color: Colors.red),
              ),
          ],
        ),
        trailing: _buildTrailingSection(context, booking, status, hasFcmToken),
        onTap: () {
          if (_selectMode) {
            setState(() {
              if (isSelected) {
                _selectedBookings.remove(bookingId);
              } else {
                _selectedBookings.add(bookingId);
              }
              if (_selectedBookings.isEmpty) {
                _selectMode = false;
              }
            });
          } else {
            // Показываем детали
            _showBookingDetails(context, booking);
          }
        },
        onLongPress: () {
          setState(() {
            _selectMode = true;
            _selectedBookings.add(bookingId);
          });
        },
      ),
    );
  }

  Widget _buildLeadingSection(
    Map<String, dynamic> booking,
    ReminderStatus status,
    bool isSelected,
  ) {
    if (_selectMode) {
      return Checkbox(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _selectedBookings.add(booking['id'] as String);
            } else {
              _selectedBookings.remove(booking['id'] as String);
            }
          });
        },
      );
    }

    // Иконка статуса
    IconData icon;
    Color color;
    switch (status) {
      case ReminderStatus.sending:
        icon = Icons.hourglass_top;
        color = Colors.orange;
        break;
      case ReminderStatus.sent:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case ReminderStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
      case ReminderStatus.pending:
      default:
        icon = Icons.notifications;
        color = Colors.blue;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, size: 20, color: color),
    );
  }

  Widget _buildTrailingSection(
    BuildContext context,
    Map<String, dynamic> booking,
    ReminderStatus status,
    bool hasFcmToken,
  ) {
    final bookingId = booking['id'] as String;

    if (status == ReminderStatus.sending) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return IconButton(
      icon: Icon(
        Icons.send,
        color: hasFcmToken && status != ReminderStatus.sent
            ? Colors.blue
            : Colors.grey,
      ),
      tooltip: 'Отправить напоминание',
      onPressed: hasFcmToken && status != ReminderStatus.sent
          ? () {
              context.read<RemindersBloc>().add(
                    SendReminder(
                      bookingId: bookingId,
                      clientId: booking['client_id'] as String,
                      clientName: booking['client_name'] as String,
                      bookingTime: booking['start_time'] as DateTime,
                      clientFCMToken: booking['fcm_token'] as String? ?? '',
                    ),
                  );
            }
          : null,
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Выбрано: ${_selectedBookings.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedBookings.clear();
                    _selectMode = false;
                  });
                },
                child: const Text('Отмена'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Отправить выбранные'),
                onPressed: () {
                  context.read<RemindersBloc>().add(
                        SendBulkReminders(_selectedBookings.toList()),
                      );
                  setState(() {
                    _selectedBookings.clear();
                    _selectMode = false;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBookingDetails(
    BuildContext context,
    Map<String, dynamic> booking,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Детали записи'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Клиент: ${booking['client_name']}'),
            Text('Услуга: ${booking['service_name']}'),
            Text(
              'Время: ${DateFormat('dd.MM.yyyy HH:mm').format(booking['start_time'] as DateTime)}',
            ),
            if (booking['comment'] != null)
              Text('Комментарий: ${booking['comment']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
