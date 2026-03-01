import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String partnerId;
  final String partnerName;
  final String? partnerAvatar;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.partnerId,
    required this.partnerName,
    this.partnerAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _supabase = Supabase.instance.client;
  late final String _currentUserId;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id ?? '';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      // Очищаем поле ввода сразу для хорошего UX
      _messageController.clear();

      await _supabase.from('messages').insert({
        'chat_id': widget.chatId,
        'sender_id': _currentUserId,
        'receiver_id': widget.partnerId,
        'text': text,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Скроллим вниз после отправки
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка отправки: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Stream<List<Map<String, dynamic>>> _getMessagesStream() {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', widget.chatId)
        .order('created_at', ascending: false) // Новые сообщения снизу (List is reversed)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  String _formatMessageTime(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr).toLocal();
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5), // Специфичный цвет фона для чата (как в TG/WA)
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.shade50,
              backgroundImage: widget.partnerAvatar != null ? NetworkImage(widget.partnerAvatar!) : null,
              child: widget.partnerAvatar == null 
                  ? Text(widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : '?', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 14))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.partnerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  // Можно добавить статус "В сети", если реализуешь это на бэке
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getMessagesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Нет сообщений. Напишите первыми!', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Переворачиваем список, чтобы новые были снизу
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message['sender_id'] == _currentUserId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final time = _formatMessageTime(message['created_at']);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue.shade600 : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    message['text'] ?? '',
                    style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(color: isMe ? Colors.blue.shade100 : Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Кнопка прикрепления (Задел на будущее - фото/файлы)
          IconButton(
            icon: Icon(Icons.attach_file_rounded, color: Colors.grey.shade500),
            onPressed: () {},
            splashRadius: 24,
          ),
          const SizedBox(width: 8),
          
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Сообщение...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onChanged: (val) {
                  // Обновляем стейт, чтобы менять иконку отправки (серая/синяя)
                  setState(() {});
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Кнопка отправки
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: _messageController.text.trim().isNotEmpty ? Colors.blue.shade600 : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.send_rounded, color: _messageController.text.trim().isNotEmpty ? Colors.white : Colors.grey.shade400, size: 20),
              onPressed: _sendMessage,
              splashRadius: 24,
            ),
          ),
        ],
      ),
    );
  }
}