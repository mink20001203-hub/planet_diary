import 'package:flutter_riverpod/flutter_riverpod.dart';

final questProvider =
    StateNotifierProvider<QuestNotifier, Map<int, List<bool>>>((ref) {
  return QuestNotifier();
});

class QuestNotifier extends StateNotifier<Map<int, List<bool>>> {
  QuestNotifier() : super({});

  void toggle(int tripDay, int questIndex) {
    final current = state[tripDay] ?? [false, false, false];
    final updated = List<bool>.from(current);
    if (questIndex < 0 || questIndex >= updated.length) return;
    updated[questIndex] = !updated[questIndex];
    state = {...state, tripDay: updated};
  }

  /// 일기 로드 시 Hive의 questDone과 동기화
  void setForDay(int tripDay, List<bool> done) {
    if (done.length != 3) return;
    state = {...state, tripDay: List<bool>.from(done)};
  }

  List<bool> getQuests(int tripDay) => state[tripDay] ?? [false, false, false];
}
