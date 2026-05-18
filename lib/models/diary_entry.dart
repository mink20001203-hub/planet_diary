import 'package:hive/hive.dart';
part 'diary_entry.g.dart';

@HiveType(typeId: 0)
class DiaryEntry extends HiveObject {
  @HiveField(0)
  final int tripDay;

  @HiveField(1)
  String text;

  @HiveField(2)
  int moodIndex;

  @HiveField(3)
  List<String> photoPaths;

  @HiveField(4)
  List<bool> questDone;

  @HiveField(5)
  DateTime savedAt;

  DiaryEntry({
    required this.tripDay,
    this.text = '',
    this.moodIndex = 0,
    List<String>? photoPaths,
    List<bool>? questDone,
    DateTime? savedAt,
  })  : photoPaths = photoPaths ?? [],
        questDone = questDone ?? [false, false, false],
        savedAt = savedAt ?? DateTime.now();

  Map<String, dynamic> toBackupJson() {
    return {
      'tripDay': tripDay,
      'text': text,
      'moodIndex': moodIndex,
      'photoPaths': photoPaths,
      'questDone': questDone,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory DiaryEntry.fromBackupJson(Map<String, dynamic> json) {
    return DiaryEntry(
      tripDay: json['tripDay'] as int,
      text: json['text'] as String? ?? '',
      moodIndex: json['moodIndex'] as int? ?? 0,
      photoPaths: (json['photoPaths'] as List<dynamic>? ?? [])
          .map((path) => path.toString())
          .toList(),
      questDone: (json['questDone'] as List<dynamic>? ?? [])
          .map((done) => done == true)
          .toList(),
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
