import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
// import '../../../chat/presentation/pages/chat_screen.dart'; // Путь к твоему экрану чата

class BookingDetailsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback
      onStatusChanged; // Коллбэк, чтобы обновить календарь после смены статуса

  const BookingDetailsBottomSheet({
    super.key,
    required this.booking,
    required this.onStatusChanged,
  });

  // Статический метод для удобного вызова
  static void show(BuildContext context, Map<String, dynamic> booking,
      VoidCallback onStatusChanged) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookingDetailsBottomSheet(
          booking: booking, onStatusChanged: onStatusChanged),
    );
  }

  @override
  State<BookingDetailsBottomSheet> createState() =>
      _BookingDetailsBottomSheetState();
}

class _BookingDetailsBottomSheetState extends State<BookingDetailsBottomSheet> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('bookings')
          .update({'status': newStatus}).eq('id', widget.booking['id']);

      if (mounted) {
        widget.onStatusChanged(); // Обновляем календарь под шторкой
        Navigator.pop(context); // Закрываем шторку

        // Показываем красивый снекбар
        final messages = {
          'confirmed': '✅ Запись подтверждена',
          'completed': '🎉 Услуга успешно завершена',
          'cancelled': '❌ Запись отменена',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(messages[newStatus] ?? 'Статус обновлен'),
            backgroundColor: newStatus == 'cancelled'
                ? Colors.red.shade600
                : Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openChat() {
    // final client = widget.booking['client'] ?? {};
    // final clientId = client['id'];
    // final clientName = client['full_name'] ?? 'Клиент';
    // final clientAvatar = client['avatar_url'];

    // Navigator.pop(context); // Закрываем шторку
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => ChatScreen(
    //       chatId: '...', // Нужно сгенерировать или найти ID чата
    //       partnerId: clientId,
    //       partnerName: clientName,
    //       partnerAvatar: clientAvatar,
    //     ),
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.booking['client'] ?? {};
    final service = widget.booking['service'] ?? {};
    final startTime = DateTime.parse(widget.booking['start_time']);
    final status = widget.booking['status'] ?? 'pending';

    return Container(
      padding: const EdgeInsets.all(24)
          .copyWith(bottom: MediaQuery.of(context).padding.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Indicator (ползунок сверху)
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),

          // Статус и время
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Детали визита',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 6),
                  Text(
                    '${DateFormat('d MMMM yyyy', 'ru_RU').format(startTime)} в ${DateFormat('HH:mm').format(startTime)}',
                    style: TextStyle(
                        fontSize: 15,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 24),

          // Карточка клиента
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white,
                  backgroundImage: client['avatar_url'] != null
                      ? NetworkImage(client['avatar_url'])
                      : null,
                  child: client['avatar_url'] == null
                      ? Icon(Icons.person_rounded,
                          color: Colors.grey.shade400, size: 28)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(client['full_name'] ?? 'Неизвестный клиент',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (client['phone'] != null) ...[
                        const SizedBox(height: 4),
                        Text(client['phone'],
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),
                // Кнопка Чата
                IconButton(
                  onPressed: _openChat,
                  icon: Icon(Icons.chat_bubble_rounded,
                      color: Colors.blue.shade600),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.shade50),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Карточка услуги
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.content_cut_rounded,
                      color: Colors.black87, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service['name'] ?? 'Услуга',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text('${service['duration_min'] ?? 60} мин',
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                Text('${service['price'] ?? 0} с.',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green.shade700)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Кнопки действий (зависят от статуса)
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildActionButtons(status),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'confirmed':
        color = Colors.blue;
        text = 'Подтверждено';
        break;
      case 'completed':
        color = Colors.green;
        text = 'Завершено';
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'Отменено';
        break;
      default: // pending
        color = Colors.orange;
        text = 'Ожидает';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.bold,
              fontSize: 12)),
    );
  }

  Widget _buildActionButtons(String status) {
    if (status == 'completed' || status == 'cancelled') {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.check_rounded, size: 20),
          label: const Text('Закрыть',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            foregroundColor: Colors.black87,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }

    return Row(
      children: [
        // Кнопка отмены
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => _updateStatus('cancelled'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade500,
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Отменить',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Главная кнопка действия (Подтвердить или Завершить)
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => _updateStatus(
                  status == 'pending' ? 'confirmed' : 'completed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'pending'
                    ? Colors.blue.shade600
                    : Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: (status == 'pending' ? Colors.blue : Colors.green)
                    .withOpacity(0.4),
              ),
              child: Text(
                status == 'pending' ? 'Подтвердить' : 'Завершить сеанс',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
