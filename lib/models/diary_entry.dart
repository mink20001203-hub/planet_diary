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
}
