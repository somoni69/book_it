import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Импорт твоего адаптивного виджета
import '../../../../core/widgets/responsive_layout.dart';

// Импорты экранов мастера
import 'master_home_screen.dart';
import 'master_journal_page.dart';
import 'hostel_calendar_page.dart';
import 'master_services_page.dart';
import '../../../profile/presentation/pages/master_profile_screen.dart';

// Импорты для BLoC (чтобы прокидывать их в Журнал)
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../data/repositories/service_repository_impl.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/hostel_calendar_bloc.dart';
import '../bloc/hostel_calendar_event.dart';

class MasterMainLayout extends StatefulWidget {
  const MasterMainLayout({super.key});

  @override
  State<MasterMainLayout> createState() => _MasterMainLayoutState();
}

class _MasterMainLayoutState extends State<MasterMainLayout> {
  int _selectedIndex = 0;
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;

  // Ленивая загрузка экранов
  List<Widget> get _pages => [
        const MasterHomeScreen(), // 0: Главная

        // 1: Журнал (Обернут в BlocProvider, как ты делал при Navigator.push)
        BlocProvider(
          create: (context) => BookingBloc(
            repository: BookingRepositoryImpl(
                BookingRemoteDataSourceImpl(Supabase.instance.client)),
            serviceRepository: ServiceRepositoryImpl(Supabase.instance.client),
            masterId: _currentUserId,
          )..add(LoadBookingsForDate(DateTime.now(), 60, '')),
          child: const MasterJournalPage(),
        ),

        // 2: Шахматка (для хостелов/посуточного бронирования)
        // HostelCalendarPage сама загружает serviceId и создаёт BLoC
        const HostelCalendarPage(),

        // 3: Услуги
        const MasterServicesPage(),

        // 4: Профиль
        const MasterProfileScreen(),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      // 📱 МОБИЛЬНАЯ ВЕРСИЯ: Нижнее меню
      mobile: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.blue.shade600,
          unselectedItemColor: Colors.grey.shade400,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded), label: 'Главная'),
            BottomNavigationBarItem(
                icon: Icon(Icons.book_online_rounded), label: 'Журнал'),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_rounded), label: 'Шахматка'),
            BottomNavigationBarItem(
                icon: Icon(Icons.content_cut_rounded), label: 'Услуги'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded), label: 'Профиль'),
          ],
        ),
      ),

      // 💻 ДЕСКТОПНАЯ ВЕРСИЯ (WEB): Боковая панель (Sidebar)
      desktop: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              extended:
                  true, // true - показывает текст, false - только иконки (можно менять в зависимости от ширины)
              backgroundColor: Colors.white,
              selectedIconTheme:
                  IconThemeData(color: Colors.blue.shade600, size: 28),
              selectedLabelTextStyle: TextStyle(
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
              unselectedIconTheme:
                  IconThemeData(color: Colors.grey.shade500, size: 24),
              unselectedLabelTextStyle:
                  TextStyle(color: Colors.grey.shade600, fontSize: 14),
              leading: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 24.0, horizontal: 16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.auto_awesome_rounded,
                          color: Colors.blue.shade600, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Text('Book IT',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: Text('Главная')),
                NavigationRailDestination(
                    icon: Icon(Icons.book_online_outlined),
                    selectedIcon: Icon(Icons.book_online_rounded),
                    label: Text('Журнал')),
                NavigationRailDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: Text('Шахматка')),
                NavigationRailDestination(
                    icon: Icon(Icons.content_cut_outlined),
                    selectedIcon: Icon(Icons.content_cut_rounded),
                    label: Text('Мои услуги')),
                NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: Text('Профиль')),
              ],
            ),
            const VerticalDivider(
                thickness: 1, width: 1, color: Color(0xFFEAECEF)),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _pages,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
