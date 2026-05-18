import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/diary_entry.dart';
import 'diary_provider.dart';

class Achievement {
  const Achievement({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
  });

  final String id;
  final String icon;
  final String title;
  final String description;
  final int current;
  final int target;

  bool get unlocked => current >= target;

  double get progress {
    if (target <= 0) return 0;
    return (current / target).clamp(0.0, 1.0);
  }
}

final achievementProvider = Provider<List<Achievement>>((ref) {
  final diaryMap = ref.watch(diaryProvider);
  final entries = diaryMap.values.toList()
    ..sort((a, b) => a.tripDay.compareTo(b.tripDay));
  final recordedDays = entries.length;
  final photoCount = entries.fold<int>(
    0,
    (sum, entry) => sum + entry.photoPaths.length,
  );
  final questCount = entries.fold<int>(
    0,
    (sum, entry) => sum + entry.questDone.where((done) => done).length,
  );
  final longestStreak = _longestStreak(entries);

  return [
    Achievement(
      id: 'first_diary',
      icon: '🚀',
      title: '첫 발사',
      description: '첫 일기를 작성하기',
      current: recordedDays,
      target: 1,
    ),
    Achievement(
      id: 'seven_streak',
      icon: '🔥',
      title: '7일 항해',
      description: '7일 연속으로 기록하기',
      current: longestStreak,
      target: 7,
    ),
    Achievement(
      id: 'photo_collector',
      icon: '📸',
      title: '우주 사진가',
      description: '사진 10장 남기기',
      current: photoCount,
      target: 10,
    ),
    Achievement(
      id: 'quest_runner',
      icon: '⭐',
      title: '퀘스트 러너',
      description: '퀘스트 30개 완료하기',
      current: questCount,
      target: 30,
    ),
    Achievement(
      id: 'monthly_log',
      icon: '🛰️',
      title: '기록 위성',
      description: '일기 15일 작성하기',
      current: recordedDays,
      target: 15,
    ),
    Achievement(
      id: 'planet_archivist',
      icon: '🪐',
      title: '행성 기록관',
      description: '일기 50일 작성하기',
      current: recordedDays,
      target: 50,
    ),
  ];
});

final unlockedAchievementCountProvider = Provider<int>((ref) {
  return ref.watch(achievementProvider).where((item) => item.unlocked).length;
});

int _longestStreak(List<DiaryEntry> entries) {
  if (entries.isEmpty) return 0;

  var longest = 1;
  var current = 1;
  var previousDay = entries.first.tripDay;

  for (final entry in entries.skip(1)) {
    if (entry.tripDay == previousDay) continue;
    if (entry.tripDay == previousDay + 1) {
      current += 1;
    } else {
      current = 1;
    }
    if (current > longest) longest = current;
    previousDay = entry.tripDay;
  }

  return longest;
}
