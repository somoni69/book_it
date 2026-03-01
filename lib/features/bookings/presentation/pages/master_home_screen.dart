import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:shimmer/shimmer.dart';

import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../data/repositories/service_repository_impl.dart';
import '../../domain/entities/booking_entity.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/create_booking_bloc.dart';
import 'create_booking_screen.dart';
import '../bloc/reminders_bloc.dart';
import 'reminders_management_screen.dart';
import 'master_journal_page.dart';
import 'master_services_page.dart';
import 'master_today_bookings_screen.dart';
import '../../../schedule/presentation/pages/working_hours_screen.dart';
import '../../../settings/pages/google_calendar_settings_screen.dart';
import '../../../reviews/presentation/pages/master_reviews_screen.dart';
import '../../../profile/presentation/pages/master_profile_screen.dart';

class MasterHomeScreen extends StatefulWidget {
  const MasterHomeScreen({super.key});

  @override
  State<MasterHomeScreen> createState() => _MasterHomeScreenState();
}

class _MasterHomeScreenState extends State<MasterHomeScreen> {
  String _masterName = '';
  String _avatarUrl = '';
  String _userInitials = '';
  int _todayBookingsCount = 0;
  bool _isLoading = true;

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(20);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadMasterInfo();
  }

  // --- ДИНАМИЧЕСКОЕ ПРИВЕТСТВИЕ ---
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Доброе утро,';
    if (hour >= 12 && hour < 18) return 'Добрый день,';
    if (hour >= 18 && hour < 23) return 'Добрый вечер,';
    return 'Доброй ночи,';
  }

  String _getInitials(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return '?';
    final parts = cleanName.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _loadMasterInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId != null) {
        final profile = await supabase
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', userId)
            .single();

        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final bookings = await supabase
            .from('bookings')
            .select('id') // Запрашиваем только ID для оптимизации трафика
            .eq('master_id', userId)
            .gte('start_time', startOfDay.toIso8601String())
            .lt('start_time', endOfDay.toIso8601String())
            .neq('status', 'cancelled');

        if (mounted) {
          final fullName = profile['full_name'] ?? 'Специалист';
          setState(() {
            _masterName = fullName;
            _avatarUrl = profile['avatar_url'] ?? '';
            _userInitials = _getInitials(fullName);
            _todayBookingsCount = (bookings as List).length;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _masterName = 'Специалист';
          _userInitials = '?';
          _isLoading = false;
        });
      }
    }
  }

  Future<List<BookingEntity>> _getNextBookings() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return [];

      final now = DateTime.now();
      final response = await supabase
          .from('bookings')
          .select('''
            *,
            client_profile:profiles!bookings_client_id_fkey(full_name),
            master_profile:profiles!bookings_master_id_fkey(full_name)
          ''')
          .eq('master_id', userId)
          .gte('start_time', now.toIso8601String())
          .neq('status', 'cancelled')
          .order('start_time', ascending: true)
          .limit(3);

      return (response as List).map((json) {
        return BookingEntity(
          id: json['id'] as String,
          masterId: json['master_id'] as String,
          clientId: json['client_id'] as String,
          serviceId: json['service_id'] as String?,
          startTime: DateTime.parse(json['start_time'] as String),
          endTime: DateTime.parse(json['end_time'] as String),
          status: _parseStatus(json['status'] as String),
          comment: json['comment'] as String?,
          clientName: json['client_profile']?['full_name'] as String? ?? 'Клиент',
          masterName: json['master_profile']?['full_name'] as String? ?? 'Мастер',
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  BookingStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return BookingStatus.pending;
      case 'confirmed': return BookingStatus.confirmed;
      case 'cancelled': return BookingStatus.cancelled;
      case 'completed': return BookingStatus.completed;
      default: return BookingStatus.pending;
    }
  }

  // Навигационные методы
  void _navigateToJournal() {
    final supabase = Supabase.instance.client;
    final dataSource = BookingRemoteDataSourceImpl(supabase);
    final repository = BookingRepositoryImpl(dataSource);
    final serviceRepository = ServiceRepositoryImpl(supabase);
    final currentUserId = supabase.auth.currentUser!.id;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => BookingBloc(
            repository: repository,
            serviceRepository: serviceRepository,
            masterId: currentUserId,
          )..add(LoadBookingsForDate(DateTime.now(), 60, '')),
          child: const MasterJournalPage(),
        ),
      ),
    );
  }

  void _navigateToSchedule() => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const WorkingHoursScreen()));
  void _navigateToServices() => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MasterServicesPage()));
  void _navigateToTodayBookings() => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MasterTodayBookingsScreen()));
  void _navigateToProfile() => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MasterProfileScreen()));

  void _navigateToReviews() {
    final currentMasterId = Supabase.instance.client.auth.currentUser?.id;
    if (currentMasterId != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => MasterReviewsScreen(masterId: currentMasterId),
      ));
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Выход из аккаунта', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: TextStyle(color: Colors.grey.shade600))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти')
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await Supabase.instance.client.auth.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Панель управления', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: const Color(0xFFF8F9FA),
        foregroundColor: Colors.black87,
        actions: [
          if (!_isLoading) ...[
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Уведомления - в разработке')));
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0, top: 8.0, bottom: 8.0),
              child: GestureDetector(
                onTap: _navigateToProfile,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue.shade100, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue.shade50,
                    backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                    child: _avatarUrl.isEmpty
                        ? Text(_userInitials, style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 13))
                        : null,
                  ),
                ),
              ),
            ),
          ]
        ],
      ),
      body: _isLoading ? _buildSkeleton() : _buildContent(),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadMasterInfo,
      color: Colors.blue.shade600,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HERO-КАРТОЧКА ---
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.indigo.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: _borderRadius,
                boxShadow: [
                  BoxShadow(color: Colors.blue.shade300.withOpacity(0.5), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_getGreeting(), style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(_masterName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 24),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _navigateToTodayBookings,
                      borderRadius: BorderRadius.circular(14),
                      highlightColor: Colors.white.withOpacity(0.1),
                      splashColor: Colors.white.withOpacity(0.2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Сегодня: $_todayBookingsCount ${_getPluralForm(_todayBookingsCount)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white.withOpacity(0.7)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // --- БЫСТРЫЕ ДЕЙСТВИЯ ---
            _buildSectionTitle('Быстрые действия'),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildQuickActionCard(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Новая запись',
                  color: Colors.blue,
                  onTap: () {
                    final userId = Supabase.instance.client.auth.currentUser?.id;
                    if (userId != null) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => BlocProvider(
                          create: (context) => CreateBookingBloc(supabase: Supabase.instance.client, masterId: userId)..add(LoadInitialData(userId)),
                          child: const CreateBookingScreen(),
                        )
                      ));
                    }
                  }
                ),
                const SizedBox(width: 12),
                _buildQuickActionCard(
                  icon: Icons.access_time_rounded,
                  label: 'Слоты',
                  color: Colors.green,
                  onTap: _navigateToSchedule
                ),
                const SizedBox(width: 12),
                _buildQuickActionCard(
                  icon: Icons.notifications_active_outlined,
                  label: 'Напоминания',
                  color: Colors.orange,
                  hasBadge: true,
                  onTap: () {
                    final userId = Supabase.instance.client.auth.currentUser?.id;
                    if (userId != null) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => BlocProvider(
                          create: (context) => RemindersBloc(supabase: Supabase.instance.client),
                          child: RemindersManagementScreen(masterId: userId),
                        )
                      ));
                    }
                  }
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQuickActionCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'Календарь',
                  color: Colors.indigo,
                  onTap: () {
                    final userId = Supabase.instance.client.auth.currentUser?.id;
                    if (userId != null) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => GoogleCalendarSettingsScreen(masterId: userId)));
                    }
                  }
                ),
                const SizedBox(width: 12),
                _buildQuickActionCard(
                  icon: Icons.settings_outlined,
                  label: 'Настройки',
                  color: Colors.grey.shade700,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке')))
                ),
                const SizedBox(width: 12),
                _buildQuickActionCard(
                  icon: Icons.help_outline_rounded,
                  label: 'Помощь',
                  color: Colors.teal,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('В разработке')))
                ),
              ],
            ),
            const SizedBox(height: 28),

            // --- БЛИЖАЙШИЕ ЗАПИСИ ---
            _buildNextBookings(),
            const SizedBox(height: 24),

            // --- УПРАВЛЕНИЕ ---
            _buildSectionTitle('Управление'),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius, boxShadow: _cardShadow),
              child: Column(
                children: [
                  _buildGroupedMenuRow(icon: Icons.book_online_rounded, title: 'Журнал записей', color: Colors.blue.shade600, onTap: _navigateToJournal),
                  Divider(height: 1, indent: 56, color: Colors.grey.shade100),
                  _buildGroupedMenuRow(icon: Icons.calendar_today_rounded, title: 'Мое расписание', color: Colors.green.shade600, onTap: _navigateToSchedule),
                  Divider(height: 1, indent: 56, color: Colors.grey.shade100),
                  _buildGroupedMenuRow(icon: Icons.content_cut_rounded, title: 'Мои услуги', color: Colors.orange.shade600, onTap: _navigateToServices),
                  Divider(height: 1, indent: 56, color: Colors.grey.shade100),
                  _buildGroupedMenuRow(icon: Icons.star_border_rounded, title: 'Отзывы клиентов', color: Colors.amber.shade600, onTap: _navigateToReviews),
                  Divider(height: 1, indent: 56, color: Colors.grey.shade100),
                  _buildGroupedMenuRow(icon: Icons.person_outline_rounded, title: 'Профиль мастера', color: Colors.purple.shade500, onTap: _navigateToProfile),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Дополнительно'),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius, boxShadow: _cardShadow),
              child: _buildGroupedMenuRow(icon: Icons.exit_to_app_rounded, title: 'Выйти из аккаунта', color: Colors.red.shade500, onTap: _handleSignOut, isDestructive: true),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87));
  }

  Widget _buildQuickActionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap, bool hasBadge = false}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _cardShadow),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      if (hasBadge)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: Center(
                      child: AutoSizeText(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        minFontSize: 10,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedMenuRow({required IconData icon, required String title, required Color color, required VoidCallback onTap, bool isDestructive = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: _borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDestructive ? Colors.red.shade600 : Colors.black87),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextBookings() {
    return FutureBuilder<List<BookingEntity>>(
      future: _getNextBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Ближайшие записи'),
              const SizedBox(height: 16),
              Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Container(height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
              ),
            ],
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();

        final bookings = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('Ближайшие записи'),
                TextButton(
                  onPressed: _navigateToJournal,
                  child: Text('Все', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade600)),
                )
              ],
            ),
            const SizedBox(height: 8),
            ...bookings.map((booking) => _buildBookingCard(booking)),
          ],
        );
      },
    );
  }

  Widget _buildBookingCard(BookingEntity booking) {
    final timeFormat = DateFormat('HH:mm');
    final isToday = DateTime.now().day == booking.startTime.day;
    final timeLeft = booking.startTime.difference(DateTime.now());

    String timeLabel;
    Color statusColor;

    if (isToday && timeLeft.inMinutes < 60 && timeLeft.inMinutes > 0) {
      timeLabel = 'Через ${timeLeft.inMinutes} мин';
      statusColor = Colors.red.shade500;
    } else if (isToday) {
      timeLabel = 'Сегодня в ${timeFormat.format(booking.startTime)}';
      statusColor = Colors.orange.shade500;
    } else {
      timeLabel = DateFormat('d MMM, HH:mm', 'ru_RU').format(booking.startTime);
      statusColor = Colors.blue.shade500;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _cardShadow, border: Border.all(color: Colors.grey.shade100)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToTodayBookings,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Center(child: Icon(Icons.access_time_filled_rounded, color: statusColor, size: 20)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.clientName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(timeLabel, style: TextStyle(fontSize: 14, color: statusColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade300),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
            const SizedBox(height: 28),
            Container(height: 24, width: 180, color: Colors.white),
            const SizedBox(height: 16),
            Row(
              children: List.generate(3, (index) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
                  height: 110,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))
                )
              )),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(3, (index) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 2 ? 12 : 0),
                  height: 110,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))
                )
              )),
            ),
            const SizedBox(height: 28),
            Container(height: 24, width: 180, color: Colors.white),
            const SizedBox(height: 16),
            Container(height: 300, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
          ],
        ),
      ),
    );
  }

  String _getPluralForm(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'запись';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return 'записи';
    return 'записей';
  }
}