import 'package:flutter/material.dart';

// Подтягиваем наши новые крутые экраны с учетом новой структуры папок!
import 'features/catalog/presentation/pages/categories_page.dart';
import 'features/bookings/presentation/pages/client_bookings_screen.dart';
import 'features/profile/presentation/pages/client_profile_screen.dart';

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _currentIndex = 0;

  // Наши 3 новых экрана для клиента
  final List<Widget> _pages = [
    const CategoriesPage(),
    const ClientBookingsScreen(),
    const ClientProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AnimatedSwitcher для плавного переключения табов
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700);
            }
            return TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          backgroundColor: Colors.white,
          elevation: 10,
          shadowColor: Colors.black.withOpacity(0.1),
          indicatorColor: Colors.blue.shade100,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
              selectedIcon:
                  Icon(Icons.search_rounded, color: Colors.blue.shade700),
              label: 'Поиск',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined,
                  color: Colors.grey.shade600),
              selectedIcon: Icon(Icons.calendar_month_rounded,
                  color: Colors.blue.shade700),
              label: 'Мои записи',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded,
                  color: Colors.grey.shade600),
              selectedIcon:
                  Icon(Icons.person_rounded, color: Colors.blue.shade700),
              label: 'Профиль',
            ),
          ],
        ),
      ),
    );
  }
}
