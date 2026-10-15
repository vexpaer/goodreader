import 'package:hive/hive.dart';

/// Chapter metadata.
///
/// For plain-text books [start]/[end] are character offsets into the decoded
/// source text. For EPUB books [href] points at the spine document inside the
/// archive and [start]/[end] are always 0.
class ChapterMeta {
  ChapterMeta({
    required this.index,
    required this.title,
    this.start = 0,
    this.end = 0,
    this.href,
  });

  final int index;
  String title;
  int start;
  int end;
  String? href;

  int get length => end - start;

  ChapterMeta copyWith({String? title, int? start, int? end, String? href}) =>
      ChapterMeta(
        index: index,
        title: title ?? this.title,
        start: start ?? this.start,
        end: end ?? this.end,
        href: href ?? this.href,
      );
}

/// All chapters of one book, stored as a single record keyed by book id.
class ChapterList {
  ChapterList({required this.bookId, required this.chapters});

  final String bookId;
  final List<ChapterMeta> chapters;

  int get length => chapters.length;
}

class ChapterMetaAdapter extends TypeAdapter<ChapterMeta> {
  @override
  final int typeId = 2;

  @override
  ChapterMeta read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{
      for (var i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    return ChapterMeta(
      index: f[0] as int,
      title: f[1] as String,
      start: (f[2] as int?) ?? 0,
      end: (f[3] as int?) ?? 0,
      href: f[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChapterMeta obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.index)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.start)
      ..writeByte(3)
      ..write(obj.end)
      ..writeByte(4)
      ..write(obj.href);
  }
}

class ChapterListAdapter extends TypeAdapter<ChapterList> {
  @override
  final int typeId = 3;

  @override
  ChapterList read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{
      for (var i = 0; i < n; i++) reader.readByte(): reader.read(),
    };
    return ChapterList(
      bookId: f[0] as String,
      chapters: (f[1] as List).cast<ChapterMeta>(),
    );
  }

  @override
  void write(BinaryWriter writer, ChapterList obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.bookId)
      ..writeByte(1)
      ..write(obj.chapters);
  }
}
