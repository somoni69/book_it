import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../data/repositories/service_repository_impl.dart';
import '../../domain/entities/booking_entity.dart';
import 'package:book_it/core/services/calendar_service.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/create_booking_bloc.dart';
import 'create_booking_screen.dart';
import '../bloc/reminders_bloc.dart';
import 'reminders_management_screen.dart';
import 'master_journal_page.dart';
import 'master_services_page.dart';
import 'master_today_bookings_screen.dart';
import 'working_hours_screen.dart';
import '../../../reviews/presentation/pages/master_reviews_screen.dart';
import '../../../master_profile/presentation/pages/master_profile_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMasterInfo();
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
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
            .select()
            .eq('master_id', userId)
            .gte('start_time', startOfDay.toIso8601String())
            .lt('start_time', endOfDay.toIso8601String())
            .neq('status', 'cancelled');

        if (mounted) {
          final fullName = profile['full_name'] ?? 'Мастер';
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
          _masterName = 'Мастер';
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
          clientName:
              json['client_profile']?['full_name'] as String? ?? 'Клиент',
          masterName:
              json['master_profile']?['full_name'] as String? ?? 'Мастер',
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  BookingStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return BookingStatus.pending;
      case 'confirmed':
        return BookingStatus.confirmed;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'completed':
        return BookingStatus.completed;
      default:
        return BookingStatus.pending;
    }
  }

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

  void _navigateToSchedule() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const WorkingHoursScreen()));
  }

  void _navigateToServices() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const MasterServicesPage()));
  }

  void _navigateToReviews() {
    final currentMasterId = Supabase.instance.client.auth.currentUser?.id;
    if (currentMasterId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MasterReviewsScreen(masterId: currentMasterId),
        ),
      );
    }
  }

  void _navigateToTodayBookings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MasterTodayBookingsScreen(),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MasterProfileScreen(),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.red)),
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Панель мастера'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Уведомления - в разработке')),
              );
            },
            tooltip: 'Уведомления',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: GestureDetector(
              onTap: _navigateToProfile,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue.shade100,
                backgroundImage:
                    _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                child: _avatarUrl.isEmpty
                    ? Text(
                        _userInitials,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMasterInfo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Добро пожаловать,',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _masterName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _navigateToTodayBookings,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Сегодня: $_todayBookingsCount ${_getPluralForm(_todayBookingsCount)}',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: Colors.blue.shade700,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildQuickActions(),
              const SizedBox(height: 20),
              _buildNextBookings(),
              const SizedBox(height: 20),
              _buildActionCard(
                icon: Icons.book_online,
                title: 'Журнал записей',
                subtitle: 'Просмотр и управление записями',
                color: Colors.blue,
                onTap: _navigateToJournal,
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.schedule,
                title: 'Мое расписание',
                subtitle: 'Управление рабочим временем',
                color: Colors.green,
                onTap: _navigateToSchedule,
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.content_cut,
                title: 'Мои услуги',
                subtitle: 'Редактирование услуг и цен',
                color: Colors.orange,
                onTap: _navigateToServices,
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.star,
                title: 'Мои отзывы',
                subtitle: 'Просмотр отзывов клиентов',
                color: Colors.amber,
                onTap: _navigateToReviews,
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.person,
                title: 'Мой профиль',
                subtitle: 'Редактирование личной информации',
                color: Colors.purple,
                onTap: _navigateToProfile,
              ),
              const SizedBox(height: 20),
              Text(
                'Дополнительно',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.settings,
                title: 'Настройки',
                subtitle: 'Общие настройки приложения',
                color: Colors.grey,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('В разработке'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.exit_to_app,
                title: 'Выход',
                subtitle: 'Выйти из аккаунта',
                color: Colors.red,
                onTap: _handleSignOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Быстрые действия',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.add_circle_outline,
                label: 'Новая запись',
                color: Colors.blue,
                onTap: () {
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  if (userId != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BlocProvider(
                          create: (context) => CreateBookingBloc(
                            supabase: Supabase.instance.client,
                            masterId: userId,
                          )..add(LoadInitialData(userId)),
                          child: const CreateBookingScreen(),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.access_time,
                label: 'Слоты',
                color: Colors.green,
                onTap: _navigateToSchedule,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.notifications_active,
                label: 'Напоминания',
                color: Colors.orange,
                onTap: () {
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  if (userId != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BlocProvider(
                          create: (context) => RemindersBloc(
                            supabase: Supabase.instance.client,
                          ),
                          child: RemindersManagementScreen(masterId: userId),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
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
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final bookings = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ближайшие записи',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
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

    if (isToday && timeLeft.inMinutes < 60) {
      timeLabel = 'Через ${timeLeft.inMinutes} мин';
      statusColor = Colors.red;
    } else if (isToday) {
      timeLabel = 'Сегодня ${timeFormat.format(booking.startTime)}';
      statusColor = Colors.orange;
    } else {
      timeLabel = DateFormat('d MMM, HH:mm', 'ru').format(booking.startTime);
      statusColor = Colors.blue;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: _navigateToTodayBookings,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.clientName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_today,
                        size: 20, color: Colors.blue),
                    onPressed: () async {
                      final description =
                          CalendarService.instance.buildBookingDescription(
                        serviceName: 'Услуга',
                        masterName: _masterName,
                        clientName: booking.clientName,
                        notes: booking.comment,
                      );

                      final success =
                          await CalendarService.instance.addBookingToCalendar(
                        title: 'Запись: ${booking.clientName}',
                        description: description,
                        startDate: booking.startTime,
                        endDate: booking.endTime,
                        reminderDuration: const Duration(hours: 1),
                      );

                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Запись ${booking.clientName} добавлена в календарь 📅'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    tooltip: 'Добавить в календарь',
                  ),
                  Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                ],
              ),
              if (booking.status != BookingStatus.completed)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _statusToText(booking.status),
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  String _getPluralForm(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'запись';
    } else if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100)) {
      return 'записи';
    } else {
      return 'записей';
    }
  }

  String _statusToText(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Ожидание';
      case BookingStatus.confirmed:
        return 'Подтверждена';
      case BookingStatus.cancelled:
        return 'Отменена';
      case BookingStatus.completed:
        return 'Завершена';
    }
  }
}
