import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final _supabase = Supabase.instance.client;
  late final String _currentUserId;

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 16,
        offset: const Offset(0, 4)),
  ];

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id ?? '';
  }

  // В реальном проекте тут будет Stream из таблицы chats/conversations
  // Для UI мы симулируем поток данных, чтобы ты мог легко подключить свою структуру БД
  Stream<List<Map<String, dynamic>>> _getChatsStream() {
    // Пример запроса к view или таблице диалогов
    return _supabase
        .from('chats') // Замени на свою таблицу диалогов
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('HH:mm').format(date);
    }
    return DateFormat('dd.MM', 'ru_RU').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Сообщения',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getChatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonList();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildChatCard(chats[index]),
          );
        },
      ),
    );
  }

  Widget _buildChatCard(Map<String, dynamic> chat) {
    // Определяем данные собеседника (в зависимости от того, кто смотрит чат)
    final isUser1 = chat['user1_id'] == _currentUserId;
    final partnerName = isUser1 ? chat['user2_name'] : chat['user1_name'];
    final partnerAvatar = isUser1 ? chat['user2_avatar'] : chat['user1_avatar'];
    final partnerId = isUser1 ? chat['user2_id'] : chat['user1_id'];

    final lastMessage = chat['last_message'] ?? 'Нет сообщений';
    final unreadCount = chat['unread_count'] ?? 0;
    final time = _formatTime(chat['updated_at']);

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: _borderRadius,
          boxShadow: _cardShadow,
          border: Border.all(color: Colors.grey.shade100)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: _borderRadius,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  chatId: chat['id'],
                  partnerId: partnerId,
                  partnerName: partnerName ?? 'Пользователь',
                  partnerAvatar: partnerAvatar,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Аватар
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blue.shade50,
                  backgroundImage: partnerAvatar != null
                      ? NetworkImage(partnerAvatar)
                      : null,
                  child: partnerAvatar == null
                      ? Text(
                          partnerName != null && partnerName.isNotEmpty
                              ? partnerName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 20))
                      : null,
                ),
                const SizedBox(width: 16),

                // Текст
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(partnerName ?? 'Без имени',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(time,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: unreadCount > 0
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade500,
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: unreadCount > 0
                                      ? Colors.black87
                                      : Colors.grey.shade600,
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.normal),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: Colors.blue.shade600,
                                  shape: BoxShape.circle),
                              child: Text(
                                  unreadCount > 99
                                      ? '99+'
                                      : unreadCount.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 56, color: Colors.blue.shade300),
          ),
          const SizedBox(height: 24),
          const Text('Нет сообщений',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Здесь будут отображаться\nваши переписки',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 15, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
        child: Text('Ошибка загрузки: $error',
            style: TextStyle(color: Colors.red.shade400)));
  }

  Widget _buildSkeletonList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
            height: 88,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: _borderRadius)),
      ),
    );
  }
}
