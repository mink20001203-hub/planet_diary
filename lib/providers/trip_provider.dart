import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      name: '수성',
      en: 'Mercury',
      days: 14,
      color: Color(0xFFB0B0B0),
      startDay: 1),
  PlanetInfo(
      name: '금성',
      en: 'Venus',
      days: 21,
      color: Color(0xFFE8C97A),
      startDay: 15),
  PlanetInfo(
      name: '지구',
      en: 'Earth',
      days: 24,
      color: Color(0xFF4A90D9),
      startDay: 36),
  PlanetInfo(
      name: '화성', en: 'Mars', days: 18, color: Color(0xFFC1440E), startDay: 60),
  PlanetInfo(
      name: '목성',
      en: 'Jupiter',
      days: 88,
      color: Color(0xFFC8A97A),
      startDay: 78),
  PlanetInfo(
      name: '토성',
      en: 'Saturn',
      days: 72,
      color: Color(0xFFE2D07A),
      startDay: 166),
  PlanetInfo(
      name: '천왕성',
      en: 'Uranus',
      days: 52,
      color: Color(0xFF7EC8E3),
      startDay: 238),
  PlanetInfo(
      name: '해왕성',
      en: 'Neptune',
      days: 76,
      color: Color(0xFF4060C8),
      startDay: 290),
];

class TripState {
  final DateTime today;
  final int tripDay;
  final PlanetInfo planet;
  final int stayDay;
  final int remainDays;

  const TripState({
    required this.today,
    required this.tripDay,
    required this.planet,
    required this.stayDay,
    required this.remainDays,
  });
}

PlanetInfo planetForDay(int day) {
  for (final p in kPlanets) {
    if (day >= p.startDay && day < p.startDay + p.days) return p;
  }
  return kPlanets.last;
}

final tripProvider = Provider<TripState>((ref) {
  final start = DateTime(2025, 1, 1);
  final today = DateTime.now();
  final raw = today.difference(start).inDays + 1;
  final tripDay = raw.clamp(1, 365);
  final planet = planetForDay(tripDay);
  return TripState(
    today: today,
    tripDay: tripDay,
    planet: planet,
    stayDay: tripDay - planet.startDay + 1,
    remainDays: planet.days - (tripDay - planet.startDay + 1),
  );
});
