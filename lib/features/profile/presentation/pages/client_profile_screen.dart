import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../../bookings/presentation/pages/client_bookings_screen.dart';
import '../../../favorites/presentation/pages/favorites_screen.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(20);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(
        color: Colors.black.withOpacity(0.03),
        blurRadius: 20,
        offset: const Offset(0, 8)),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data =
          await _supabase.from('profiles').select().eq('id', userId).single();

      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    Navigator.pushReplacementNamed(
        context, '/login'); // Твой роут на авторизацию
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Мой профиль',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: _isLoading ? _buildSkeleton() : _buildContent(),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      color: Colors.blue.shade600,
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16).copyWith(bottom: 40),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildActionGroup(
              title: 'Активность',
              items: [
                _ActionItem(
                  icon: Icons.calendar_month_rounded,
                  color: Colors.blue,
                  title: 'Мои записи',
                  subtitle: 'Предстоящие и история',
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ClientBookingsScreen()));
                  },
                ),
                _ActionItem(
                  icon: Icons.favorite_rounded,
                  color: Colors.red,
                  title: 'Избранные мастера',
                  subtitle: 'Ваши любимые специалисты',
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FavoritesScreen()));
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildActionGroup(
              title: 'Настройки',
              items: [
                _ActionItem(
                  icon: Icons.person_outline_rounded,
                  color: Colors.orange,
                  title: 'Личные данные',
                  onTap: () {},
                ),
                _ActionItem(
                  icon: Icons.notifications_none_rounded,
                  color: Colors.purple,
                  title: 'Уведомления',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: Icon(Icons.logout_rounded, color: Colors.red.shade400),
                label: Text('Выйти из аккаунта',
                    style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  backgroundColor: Colors.red.shade50.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _profileData?['full_name'] ?? 'Без имени';
    final email = _supabase.auth.currentUser?.email ?? '';
    final avatarUrl = _profileData?['avatar_url'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: _borderRadius,
          boxShadow: _cardShadow,
          border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.blue.shade50,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text(email,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.grey.shade50, shape: BoxShape.circle),
            child:
                Icon(Icons.edit_rounded, size: 20, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildActionGroup(
      {required String title, required List<_ActionItem> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                  textBaseline: TextBaseline.alphabetic)),
        ),
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _borderRadius,
              boxShadow: _cardShadow,
              border: Border.all(color: Colors.grey.shade100)),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isLast = index == items.length - 1;

              return Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: item.onTap,
                      borderRadius: index == 0
                          ? const BorderRadius.vertical(
                              top: Radius.circular(20))
                          : isLast
                              ? const BorderRadius.vertical(
                                  bottom: Radius.circular(20))
                              : BorderRadius.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: item.color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12)),
                              child:
                                  Icon(item.icon, color: item.color, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87)),
                                  if (item.subtitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(item.subtitle!,
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade500)),
                                  ],
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: Colors.grey.shade300),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 64, color: Colors.grey.shade100),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
                height: 110,
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: _borderRadius)),
            const SizedBox(height: 32),
            Container(
                height: 160,
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: _borderRadius)),
            const SizedBox(height: 32),
            Container(
                height: 160,
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: _borderRadius)),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  _ActionItem(
      {required this.icon,
      required this.color,
      required this.title,
      this.subtitle,
      required this.onTap});
}
