import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/review_repository_impl.dart';

class ReviewScreen extends StatefulWidget {
  final String bookingId;
  final String masterId;
  final String masterName;
  final String serviceName;

  const ReviewScreen({
    super.key,
    required this.bookingId,
    required this.masterId,
    required this.masterName,
    required this.serviceName,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final ReviewRepositoryImpl _reviewRepo;
  int _selectedRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
  ];

  @override
  void initState() {
    super.initState();
    _reviewRepo = ReviewRepositoryImpl(Supabase.instance.client);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Пожалуйста, напишите пару слов о визите'), backgroundColor: Colors.orange.shade600, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentClientId = Supabase.instance.client.auth.currentUser?.id;
      if (currentClientId == null) throw Exception('Пользователь не авторизован');

      await _reviewRepo.createReview(
        bookingId: widget.bookingId,
        masterId: widget.masterId,
        clientId: currentClientId,
        rating: _selectedRating,
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('✅ Спасибо за ваш отзыв!'), backgroundColor: Colors.green.shade600, behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}'), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Оставить отзыв', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20).copyWith(bottom: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
              child: Icon(Icons.celebration_rounded, size: 48, color: Colors.blue.shade400),
            ),
            const SizedBox(height: 24),
            const Text('Как прошел ваш визит?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Оцените работу мастера ${widget.masterName}', style: TextStyle(fontSize: 16, color: Colors.grey.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 32),

            // Карточка услуги
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius, boxShadow: _cardShadow, border: Border.all(color: Colors.grey.shade100)),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.content_cut_rounded, color: Colors.blue.shade600, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.serviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade500),
                            const SizedBox(width: 4),
                            Text('Услуга завершена', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Выбор звезд
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isSelected = starIndex <= _selectedRating;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = starIndex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 52,
                      color: isSelected ? Colors.amber.shade400 : Colors.grey.shade300,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _getRatingText(_selectedRating),
                key: ValueKey<int>(_selectedRating),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _getRatingColor(_selectedRating)),
              ),
            ),
            const SizedBox(height: 40),

            // Поле комментария
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Ваш комментарий', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Расскажите, что понравилось больше всего...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                counterStyle: TextStyle(color: Colors.grey.shade500),
                enabledBorder: OutlineInputBorder(borderRadius: _borderRadius, borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: _borderRadius, borderSide: BorderSide(color: Colors.blue.shade400, width: 2)),
              ),
            ),
            const SizedBox(height: 32),

            // Кнопки
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.blue.shade300,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: Colors.blue.withOpacity(0.4),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Отправить отзыв', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
              child: const Text('Пропустить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1: return 'Ужасно 😞';
      case 2: return 'Плохо 😕';
      case 3: return 'Нормально 😐';
      case 4: return 'Хорошо 🙂';
      case 5: return 'Отлично! 😍';
      default: return '';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating <= 2) return Colors.red.shade400;
    if (rating == 3) return Colors.orange.shade400;
    return Colors.green.shade500;
  }
}