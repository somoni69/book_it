import 'package:flutter/material.dart';

/// Универсальный виджет для адаптивного отображения интерфейса
/// в зависимости от ширины экрана устройства.
///
/// Три состояния:
/// - Mobile: < 600px (телефоны)
/// - Tablet: 600px - 1200px (планшеты)
/// - Desktop: > 1200px (ПК/ноутбуки)
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// Точка перехода к планшету
  static const int tabletBreakpoint = 600;

  /// Точка перехода к десктопу
  static const int desktopBreakpoint = 1200;

  /// Проверяет, является ли текущий экран мобильным
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tabletBreakpoint;

  /// Проверяет, является ли текущий экран планшетом
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletBreakpoint && width < desktopBreakpoint;
  }

  /// Проверяет, является ли текущий экран десктопом
  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Desktop (> 1200px)
        if (width >= desktopBreakpoint) {
          return desktop ?? tablet ?? mobile;
        }

        // Tablet (600px - 1200px)
        if (width >= tabletBreakpoint) {
          return tablet ?? mobile;
        }

        // Mobile (< 600px)
        return mobile;
      },
    );
  }
}
