import 'package:hive/hive.dart';

enum NoteType { highlight, bookmark, thought }

/// A highlight / bookmark / thought attached to a position in a book.
class BookNote {
  BookNote({
    required this.id,
    required this.bookId,
    required this.type,
    required this.chapterIndex,
    this.start = 0,
    this.end = 0,
    this.text = '',
    this.note = '',
    this.color = 0xFFFFD54F,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String bookId;
  NoteType type;
  int chapterIndex;
  int start;
  int end;

  /// The quoted source text.
  String text;

  /// User commentary.
  String note;
  int color;
  DateTime createdAt;

  BookNote copyWith({String? note, int? color, String? text}) => BookNote(
        id: id,
        bookId: bookId,
        type: type,
        chapterIndex: chapterIndex,
        start: start,
        end: end,
        text: text ?? this.text,
        note: note ?? this.note,
        color: color ?? this.color,
        createdAt: createdAt,
      );
}

class BookNoteAdapter extends TypeAdapter<BookNote> {
  @override
  final int typeId = 4;

  @override
  BookNote read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{
      for (var i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    return BookNote(
      id: f[0] as String,
      bookId: f[1] as String,
      type: NoteType.values[(f[2] as int?) ?? 0],
      chapterIndex: (f[3] as int?) ?? 0,
      start: (f[4] as int?) ?? 0,
      end: (f[5] as int?) ?? 0,
      text: (f[6] as String?) ?? '',
      note: (f[7] as String?) ?? '',
      color: (f[8] as int?) ?? 0xFFFFD54F,
      createdAt: DateTime.fromMillisecondsSinceEpoch((f[9] as int?) ?? 0),
    );
  }

  @override
  void write(BinaryWriter writer, BookNote obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.bookId)
      ..writeByte(2)
      ..write(obj.type.index)
      ..writeByte(3)
      ..write(obj.chapterIndex)
      ..writeByte(4)
      ..write(obj.start)
      ..writeByte(5)
      ..write(obj.end)
      ..writeByte(6)
      ..write(obj.text)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.color)
      ..writeByte(9)
      ..write(obj.createdAt.millisecondsSinceEpoch);
  }
}
