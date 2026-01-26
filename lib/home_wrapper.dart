import 'package:flutter/material.dart';
import 'features/bookings/presentation/pages/categories_page.dart';
import 'features/bookings/presentation/pages/master_journal_page.dart';

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const CategoriesPage(),
    const MasterJournalPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Запись (Клиент)',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Журнал (Мастер)',
          ),
        ],
      ),
    );
  }
}
