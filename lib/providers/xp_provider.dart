import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class XpState {
  final int totalXp;
  final int level;
  final int streak;
  final int lastSavedDay;

  const XpState({
    this.totalXp = 0,
    this.level = 1,
    this.streak = 0,
    this.lastSavedDay = 0,
  });

  XpState copyWith({
    int? totalXp,
    int? level,
    int? streak,
    int? lastSavedDay,
  }) {
    return XpState(
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      streak: streak ?? this.streak,
      lastSavedDay: lastSavedDay ?? this.lastSavedDay,
    );
  }
}

class XpNotifier extends StateNotifier<XpState> {
  XpNotifier() : super(const XpState()) {
    _load();
  }

  void _load() {
    final box = Hive.box('xp');
    state = XpState(
      totalXp: box.get('totalXp', defaultValue: 0),
      level: box.get('level', defaultValue: 1),
      streak: box.get('streak', defaultValue: 0),
      lastSavedDay: box.get('lastSavedDay', defaultValue: 0),
    );
  }

  bool addXp(int amount) {
    final box = Hive.box('xp');
    final newXp = state.totalXp + amount;
    final newLevel = (newXp / 100).floor() + 1;
    final leveledUp = newLevel > state.level;
    state = state.copyWith(totalXp: newXp, level: newLevel);
    box.put('totalXp', newXp);
    box.put('level', newLevel);
    return leveledUp;
  }

  void checkStreak(int tripDay) {
    final box = Hive.box('xp');
    final last = state.lastSavedDay;
    
    // 같은 날짜 중복 저장은 무시
    if (tripDay == last) return;

    final newStreak = (tripDay - last == 1) ? state.streak + 1 : 1;
    if (newStreak > 0 && newStreak % 3 == 0) addXp(20);
    
    state = state.copyWith(streak: newStreak, lastSavedDay: tripDay);
    box.put('streak', newStreak);
    box.put('lastSavedDay', tripDay);
  }
}

final xpProvider = StateNotifierProvider<XpNotifier, XpState>((ref) {
  return XpNotifier();
});
