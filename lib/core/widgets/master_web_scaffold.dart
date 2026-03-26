import 'package:flutter/material.dart';
import 'responsive_layout.dart';
import '../../features/bookings/presentation/pages/master_home_screen.dart';

class MasterWebScaffold extends StatefulWidget {
  const MasterWebScaffold({super.key});

  @override
  State<MasterWebScaffold> createState() => _MasterWebScaffoldState();
}

class _MasterWebScaffoldState extends State<MasterWebScaffold> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const MasterHomeScreen(), // Главная дашборд-панель
    const Center(
        child: Text(
            'Журнал записей (В разработке)')), // Сюда вставишь MasterJournalPage
    const Center(
        child: Text(
            'Мои услуги (В разработке)')), // Сюда вставишь MasterServicesPage
    const Center(
        child: Text(
            'Профиль (В разработке)')), // Сюда вставишь MasterProfileScreen
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      // 📱 МОБИЛЬНЫЙ ИНТЕРФЕЙС
      mobile: Scaffold(
        body: _pages[_selectedIndex],
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
                icon: Icon(Icons.content_cut_rounded), label: 'Услуги'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded), label: 'Профиль'),
          ],
        ),
      ),

      // 💻 ДЕСКТОПНЫЙ ИНТЕРФЕЙС (WEB)
      desktop: Scaffold(
        backgroundColor:
            const Color(0xFFF3F4F6), // Чуть серый фон для контраста
        body: Row(
          children: [
            // Боковое меню (Sidebar)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              extended: true, // true - показывает текст, false - только иконки
              backgroundColor: Colors.white,
              selectedIconTheme: IconThemeData(color: Colors.blue.shade600),
              selectedLabelTextStyle: TextStyle(
                  color: Colors.blue.shade600, fontWeight: FontWeight.bold),
              unselectedIconTheme: IconThemeData(color: Colors.grey.shade500),
              unselectedLabelTextStyle: TextStyle(color: Colors.grey.shade600),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: Colors.blue.shade600, size: 28),
                    const SizedBox(width: 8),
                    const Text('CRM',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
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
                    icon: Icon(Icons.content_cut_outlined),
                    selectedIcon: Icon(Icons.content_cut_rounded),
                    label: Text('Мои услуги')),
                NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: Text('Профиль')),
              ],
            ),

            // Вертикальная линия-разделитель
            const VerticalDivider(
                thickness: 1, width: 1, color: Color(0xFFE5E7EB)),

            // Основная рабочая область
            Expanded(
              child: ClipRRect(
                // Небольшой трюк: закругляем контент в десктопе, чтобы выглядело как SaaS
                child: _pages[_selectedIndex],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
