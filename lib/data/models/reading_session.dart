import 'package:hive/hive.dart';

/// One continuous reading stint, used for statistics.
class ReadingSession {
  ReadingSession({
    required this.id,
    required this.bookId,
    required this.startedAt,
    required this.seconds,
    this.chars = 0,
  });

  final String id;
  final String bookId;
  final DateTime startedAt;
  int seconds;
  int chars;

  /// Local day key `yyyy-MM-dd`, handy for heat maps.
  String get dayKey => '${startedAt.year.toString().padLeft(4, '0')}-'
      '${startedAt.month.toString().padLeft(2, '0')}-'
      '${startedAt.day.toString().padLeft(2, '0')}';
}

class ReadingSessionAdapter extends TypeAdapter<ReadingSession> {
  @override
  final int typeId = 5;

  @override
  ReadingSession read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{
      for (var i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    return ReadingSession(
      id: f[0] as String,
      bookId: f[1] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch((f[2] as int?) ?? 0),
      seconds: (f[3] as int?) ?? 0,
      chars: (f[4] as int?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, ReadingSession obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.startedAt.millisecondsSinceEpoch)
      ..writeByte(3)
      ..write(obj.seconds)
      ..writeByte(4)
      ..write(obj.chars);
  }
}
