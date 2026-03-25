import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/diary_entry.dart';

final diaryProvider =
    StateNotifierProvider<DiaryNotifier, Map<int, DiaryEntry>>((ref) {
  return DiaryNotifier();
});

class DiaryNotifier extends StateNotifier<Map<int, DiaryEntry>> {
  DiaryNotifier() : super({}) {
    _load();
  }

  void _load() {
    final box = Hive.box<DiaryEntry>('diary');
    final map = <int, DiaryEntry>{};
    for (final entry in box.values) {
      map[entry.tripDay] = entry;
    }
    state = map;
  }

  Future<void> save(DiaryEntry entry) async {
    final box = Hive.box<DiaryEntry>('diary');
    await box.put(entry.tripDay, entry);
    state = {...state, entry.tripDay: entry};
  }

  DiaryEntry? get(int tripDay) => state[tripDay];
}
