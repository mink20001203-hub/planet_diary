// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DiaryEntryAdapter extends TypeAdapter<DiaryEntry> {
  @override
  final int typeId = 0;

  @override
  DiaryEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DiaryEntry(
      tripDay: fields[0] as int,
      text: fields[1] as String,
      moodIndex: fields[2] as int,
      photoPaths: (fields[3] as List?)?.cast<String>(),
      questDone: (fields[4] as List?)?.cast<bool>(),
      savedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DiaryEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.tripDay)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.moodIndex)
      ..writeByte(3)
      ..write(obj.photoPaths)
      ..writeByte(4)
      ..write(obj.questDone)
      ..writeByte(5)
      ..write(obj.savedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaryEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
