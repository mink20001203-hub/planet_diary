import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PlanetInfo {
  final String name;
  final String en;
  final int days;
  final Color color;
  final int startDay;

  const PlanetInfo({
    required this.name,
    required this.en,
    required this.days,
    required this.color,
    required this.startDay,
  });
}

const List<PlanetInfo> kPlanets = [
  PlanetInfo(
    name: '\uC218\uC131',
    en: 'Mercury',
    days: 14,
    color: Color(0xFFB0B0B0),
    startDay: 1,
  ),
  PlanetInfo(
    name: '\uAE08\uC131',
    en: 'Venus',
    days: 21,
    color: Color(0xFFE8C97A),
    startDay: 15,
  ),
  PlanetInfo(
    name: '\uC9C0\uAD6C',
    en: 'Earth',
    days: 24,
    color: Color(0xFF4A90D9),
    startDay: 36,
  ),
  PlanetInfo(
    name: '\uD654\uC131',
    en: 'Mars',
    days: 18,
    color: Color(0xFFC1440E),
    startDay: 60,
  ),
  PlanetInfo(
    name: '\uBAA9\uC131',
    en: 'Jupiter',
    days: 88,
    color: Color(0xFFC8A97A),
    startDay: 78,
  ),
  PlanetInfo(
    name: '\uD1A0\uC131',
    en: 'Saturn',
    days: 72,
    color: Color(0xFFE2D07A),
    startDay: 166,
  ),
  PlanetInfo(
    name: '\uCC9C\uC655\uC131',
    en: 'Uranus',
    days: 52,
    color: Color(0xFF7EC8E3),
    startDay: 238,
  ),
  PlanetInfo(
    name: '\uD574\uC655\uC131',
    en: 'Neptune',
    days: 76,
    color: Color(0xFF4060C8),
    startDay: 290,
  ),
];

class TripState {
  final DateTime today;
  final DateTime startDate;
  final int tripDay;
  final PlanetInfo planet;
  final int stayDay;
  final int remainDays;

  const TripState({
    required this.today,
    required this.startDate,
    required this.tripDay,
    required this.planet,
    required this.stayDay,
    required this.remainDays,
  });
}

PlanetInfo planetForDay(int day) {
  for (final p in kPlanets) {
    if (day >= p.startDay && day < p.startDay + p.days) {
      return p;
    }
  }
  return kPlanets.last;
}

class TripNotifier extends StateNotifier<TripState> {
  TripNotifier() : super(_calculateState(DateTime.now())) {
    _loadStartDate();
  }

  static TripState _calculateState(DateTime start) {
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final now = DateTime.now();
    final raw = now.difference(normalizedStart).inDays + 1;
    final tripDay = raw.clamp(1, 365);
    final planet = planetForDay(tripDay);
    final stayDay = tripDay - planet.startDay + 1;

    return TripState(
      today: now,
      startDate: normalizedStart,
      tripDay: tripDay,
      planet: planet,
      stayDay: stayDay,
      remainDays: planet.days - stayDay,
    );
  }

  Future<void> _loadStartDate() async {
    final box = await Hive.openBox('settings');
    final startMillis = box.get('tripStartDate');
    final start = startMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(startMillis as int)
        : DateTime.now();
    state = _calculateState(start);
  }

  Future<void> setStartDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final box = await Hive.openBox('settings');
    await box.put('tripStartDate', normalized.millisecondsSinceEpoch);
    state = _calculateState(normalized);
  }
}

final tripProvider = StateNotifierProvider<TripNotifier, TripState>((ref) {
  return TripNotifier();
});
