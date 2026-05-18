import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/space_map_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/diary_edit_screen.dart';

import 'screens/monthly_recap_screen.dart';
import 'screens/recap_screen.dart';
import 'screens/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SpaceMapScreen(),
        transitionsBuilder: _fadeTransition,
      ),
    ),
    GoRoute(
      path: '/calendar',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const CalendarScreen(),
        transitionsBuilder: _fadeTransition,
      ),
    ),
    GoRoute(
      path: '/recap',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const RecapScreen(),
        transitionsBuilder: _fadeTransition,
      ),
    ),
    GoRoute(
      path: '/monthly-recap/:year/:month',
      pageBuilder: (context, state) {
        final year = int.parse(state.pathParameters['year']!);
        final month = int.parse(state.pathParameters['month']!);
        return CustomTransitionPage(
          key: state.pageKey,
          child: MonthlyRecapScreen(year: year, month: month),
          transitionsBuilder: _fadeTransition,
        );
      },
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SettingsScreen(),
        transitionsBuilder: _fadeTransition,
      ),
    ),
    GoRoute(
      path: '/diary/:tripDay',
      pageBuilder: (context, state) {
        final tripDay = int.parse(state.pathParameters['tripDay']!);
        return CustomTransitionPage(
          key: state.pageKey,
          child: DiaryEditScreen(tripDay: tripDay),
          transitionsBuilder: _slideUpTransition,
        );
      },
    ),
  ],
);

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    ),
    child: child,
  );
}

Widget _slideUpTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    )),
    child: FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.8),
      ),
      child: child,
    ),
  );
}
