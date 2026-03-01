import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../bloc/reminders_bloc.dart';

class RemindersManagementScreen extends StatefulWidget {
  final String masterId;
  const RemindersManagementScreen({super.key, required this.masterId});

  @override
  State<RemindersManagementScreen> createState() => _RemindersManagementScreenState();
}

class _RemindersManagementScreenState extends State<RemindersManagementScreen> {
  final Set<String> _selectedBookings = {};
  bool _selectMode = false;

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RemindersBloc>().add(LoadReminders(widget.masterId));
    });
  }

  void _toggleSelection(String bookingId) {
    setState(() {
      if (_selectedBookings.contains(bookingId)) {
        _selectedBookings.remove(bookingId);
        if (_selectedBookings.isEmpty) _selectMode = false;
      } else {
        _selectedBookings.add(bookingId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedBookings.clear();
      _selectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildAppBar(context),
      body: BlocConsumer<RemindersBloc, RemindersState>(
        listener: (context, state) {
          if (state is RemindersError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating),
            );
          }
        },
        builder: (context, state) {
          if (state is RemindersInitial || state is RemindersLoading) {
            return _buildSkeletonList();
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
      bottomNavigationBar: _selectMode && _selectedBookings.isNotEmpty ? _buildBottomActionBar(context) : null,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    if (_selectMode) {
      return AppBar(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _clearSelection),
        title: Text('Выбрано: ${_selectedBookings.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all_rounded),
            tooltip: 'Выбрать все',
            onPressed: () {
              final state = context.read<RemindersBloc>().state;
              if (state is RemindersLoaded) {
                setState(() {
                  final validBookings = state.bookingsNeedingReminder.where((b) => b['fcm_token'] != null).map((b) => b['id'] as String);
                  _selectedBookings.addAll(validBookings);
                });
              }
            },
          ),
        ],
      );
    }

    return AppBar(
      title: const Text('Напоминания', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.05),
      actions: [
        BlocBuilder<RemindersBloc, RemindersState>(
          builder: (context, state) {
            if (state is! RemindersLoaded) return const SizedBox();
            final needsReminder = state.bookingsNeedingReminder.where((b) => b['fcm_token'] != null).toList();
            if (needsReminder.isEmpty) return const SizedBox();

            return IconButton(
              icon: Icon(Icons.send_rounded, color: Colors.blue.shade600),
              tooltip: 'Отправить все',
              onPressed: state.isSending
                  ? null
                  : () {
                      final bookingIds = needsReminder.map((b) => b['id'] as String).toList();
                      context.read<RemindersBloc>().add(SendBulkReminders(bookingIds));
                    },
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Обновить',
          onPressed: () => context.read<RemindersBloc>().add(LoadReminders(widget.masterId)),
        ),
      ],
    );
  }

  Widget _buildSkeletonList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
          const SizedBox(height: 24),
          ...List.generate(5, (_) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius),
          )),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, RemindersError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(state.message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<RemindersBloc>().add(LoadReminders(widget.masterId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить попытку'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context, RemindersLoaded state) {
    final bookings = state.bookingsNeedingReminder;

    if (bookings.isEmpty) return _buildEmptyState(context);

    return Column(
      children: [
        _buildStatsCard(state),
        Expanded(
          child: RefreshIndicator(
            color: Colors.blue.shade600,
            onRefresh: () async => context.read<RemindersBloc>().add(LoadReminders(widget.masterId)),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 100),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: bookings.length,
              itemBuilder: (context, index) => _buildBookingCard(context, bookings[index], state),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Icon(Icons.notifications_off_rounded, size: 56, color: Colors.blue.shade300),
          ),
          const SizedBox(height: 24),
          const Text('Нет записей для напоминаний', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Записи, требующие напоминания, появятся здесь за 24 часа до начала сеанса',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Обновить', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => context.read<RemindersBloc>().add(LoadReminders(widget.masterId)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(RemindersLoaded state) {
    final total = state.bookingsNeedingReminder.length;
    final sent = state.sentCount;
    final progress = total > 0 ? sent / total : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius, boxShadow: _cardShadow),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(icon: Icons.access_time_filled_rounded, value: '$total', label: 'Ожидают', color: Colors.orange.shade500),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _buildStatItem(icon: Icons.check_circle_rounded, value: '$sent', label: 'Отправлено', color: Colors.green.shade500),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({required IconData icon, required String value, required String label, required Color color}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> booking, RemindersLoaded state) {
    final bookingId = booking['id'] as String;
    final status = state.reminderStatuses[bookingId] ?? ReminderStatus.pending;
    final isSelected = _selectedBookings.contains(bookingId);
    final hasFcmToken = booking['fcm_token'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        borderRadius: _borderRadius,
        boxShadow: _cardShadow,
        border: Border.all(color: isSelected ? Colors.blue.shade200 : Colors.grey.shade100, width: isSelected ? 2 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: _borderRadius,
          onTap: () {
            if (_selectMode) {
              if (hasFcmToken) _toggleSelection(bookingId);
            } else {
              _showBookingDetailsBottomSheet(context, booking);
            }
          },
          onLongPress: () {
            if (hasFcmToken && status != ReminderStatus.sent) {
              setState(() {
                _selectMode = true;
                _selectedBookings.add(bookingId);
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildLeadingSection(status, isSelected, hasFcmToken),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking['client_name'] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: hasFcmToken ? Colors.black87 : Colors.grey.shade500)),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, d MMM • HH:mm', 'ru_RU').format(booking['start_time'] as DateTime),
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(booking['service_name'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      if (!hasFcmToken) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 12, color: Colors.red.shade400),
                              const SizedBox(width: 4),
                              Text('Нет доступа к PUSH', style: TextStyle(fontSize: 10, color: Colors.red.shade600, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildTrailingSection(context, booking, status, hasFcmToken),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingSection(ReminderStatus status, bool isSelected, bool hasFcmToken) {
    if (_selectMode && hasFcmToken) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.blue.shade600 : Colors.grey.shade100),
        child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white) : const SizedBox(),
      );
    }

    IconData icon;
    Color color;
    Color bgColor;

    switch (status) {
      case ReminderStatus.sending:
        icon = Icons.sync_rounded;
        color = Colors.orange.shade600;
        bgColor = Colors.orange.shade50;
        break;
      case ReminderStatus.sent:
        icon = Icons.check_circle_rounded;
        color = Colors.green.shade600;
        bgColor = Colors.green.shade50;
        break;
      case ReminderStatus.failed:
        icon = Icons.error_rounded;
        color = Colors.red.shade600;
        bgColor = Colors.red.shade50;
        break;
      case ReminderStatus.pending:
        icon = Icons.notifications_active_rounded;
        color = hasFcmToken ? Colors.blue.shade500 : Colors.grey.shade400;
        bgColor = hasFcmToken ? Colors.blue.shade50 : Colors.grey.shade100;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
      child: Icon(icon, size: 22, color: color),
    );
  }

  Widget _buildTrailingSection(BuildContext context, Map<String, dynamic> booking, ReminderStatus status, bool hasFcmToken) {
    if (status == ReminderStatus.sending) {
      return SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange.shade400));
    }
    if (status == ReminderStatus.sent) {
      return Icon(Icons.done_all_rounded, color: Colors.green.shade400);
    }

    return IconButton(
      icon: Icon(Icons.send_rounded, color: hasFcmToken ? Colors.blue.shade600 : Colors.grey.shade300),
      tooltip: 'Отправить напоминание',
      style: IconButton.styleFrom(backgroundColor: hasFcmToken ? Colors.blue.shade50 : Colors.transparent),
      onPressed: hasFcmToken
          ? () {
              context.read<RemindersBloc>().add(
                SendReminder(
                  bookingId: booking['id'] as String,
                  clientId: booking['client_id'] as String,
                  clientName: booking['client_name'] as String,
                  bookingTime: booking['start_time'] as DateTime,
                  clientFCMToken: booking['fcm_token'] as String,
                ),
              );
            }
          : null,
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 32),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded, size: 20),
            label: const Text('Отправить выбранные', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: Colors.blue.withOpacity(0.4),
            ),
            onPressed: () {
              context.read<RemindersBloc>().add(SendBulkReminders(_selectedBookings.toList()));
              _clearSelection();
            },
          ),
        ),
      ),
    );
  }

  void _showBookingDetailsBottomSheet(BuildContext context, Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const Text('Детали записи', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 24),
            _buildDetailRow(Icons.person_outline_rounded, 'Клиент', booking['client_name'] as String),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.content_cut_rounded, 'Услуга', booking['service_name'] as String),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.calendar_today_rounded, 'Дата и время', DateFormat('dd.MM.yyyy • HH:mm').format(booking['start_time'] as DateTime)),
            if (booking['comment'] != null && booking['comment'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDetailRow(Icons.chat_bubble_outline_rounded, 'Комментарий', booking['comment'] as String),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade100, foregroundColor: Colors.black87, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: Colors.blue.shade600),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}