import 'package:hive/hive.dart';

/// Supported book formats.
enum BookFormat { txt, epub, pdf, mobi, azw3, cbz, unknown }

extension BookFormatX on BookFormat {
  String get label => switch (this) {
        BookFormat.txt => 'TXT',
        BookFormat.epub => 'EPUB',
        BookFormat.pdf => 'PDF',
        BookFormat.mobi => 'MOBI',
        BookFormat.azw3 => 'AZW3',
        BookFormat.cbz => 'CBZ',
        BookFormat.unknown => '?',
      };

  static BookFormat fromExtension(String ext) => switch (ext.toLowerCase()) {
        'txt' => BookFormat.txt,
        'epub' => BookFormat.epub,
        'pdf' => BookFormat.pdf,
        'mobi' => BookFormat.mobi,
        'azw' || 'azw3' => BookFormat.azw3,
        'cbz' || 'cbr' => BookFormat.cbz,
        _ => BookFormat.unknown,
      };
}

/// A single book on the shelf.
class Book {
  Book({
    required this.id,
    required this.title,
    this.author = '',
    this.intro = '',
    this.coverPath,
    required this.filePath,
    required this.format,
    this.fileSize = 0,
    this.chapterCount = 0,
    this.encoding = 'utf-8',
    this.chapterRule,
    DateTime? addedAt,
    DateTime? updatedAt,
    this.lastReadAt,
    this.lastChapterIndex = 0,
    this.lastOffset = 0,
    this.progress = 0,
    this.isFavorite = false,
    this.isPrivate = false,
    List<String>? tags,
    this.groupId,
    this.seriesName,
    this.seriesIndex,
  })  : addedAt = addedAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        tags = tags ?? <String>[];

  final String id;
  String title;
  String author;
  String intro;
  String? coverPath;
  String filePath;
  BookFormat format;
  int fileSize;
  int chapterCount;
  String encoding;

  /// Optional user supplied regex used to split TXT into chapters.
  String? chapterRule;

  DateTime addedAt;
  DateTime updatedAt;
  DateTime? lastReadAt;

  /// Index of the chapter the reader should restore to.
  int lastChapterIndex;

  /// Character offset inside [lastChapterIndex].
  int lastOffset;

  /// 0..1 overall progress.
  double progress;

  bool isFavorite;
  bool isPrivate;
  List<String> tags;
  String? groupId;
  String? seriesName;
  int? seriesIndex;

  String get displayAuthor => author.trim().isEmpty ? '佚名' : author.trim();

  Book copyWith({
    String? title,
    String? author,
    String? intro,
    String? coverPath,
    String? filePath,
    BookFormat? format,
    int? fileSize,
    int? chapterCount,
    String? encoding,
    String? chapterRule,
    DateTime? addedAt,
    DateTime? updatedAt,
    DateTime? lastReadAt,
    int? lastChapterIndex,
    int? lastOffset,
    double? progress,
    bool? isFavorite,
    bool? isPrivate,
    List<String>? tags,
    String? groupId,
    String? seriesName,
    int? seriesIndex,
  }) =>
      Book(
        id: id,
        title: title ?? this.title,
        author: author ?? this.author,
        intro: intro ?? this.intro,
        coverPath: coverPath ?? this.coverPath,
        filePath: filePath ?? this.filePath,
        format: format ?? this.format,
        fileSize: fileSize ?? this.fileSize,
        chapterCount: chapterCount ?? this.chapterCount,
        encoding: encoding ?? this.encoding,
        chapterRule: chapterRule ?? this.chapterRule,
        addedAt: addedAt ?? this.addedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastReadAt: lastReadAt ?? this.lastReadAt,
        lastChapterIndex: lastChapterIndex ?? this.lastChapterIndex,
        lastOffset: lastOffset ?? this.lastOffset,
        progress: progress ?? this.progress,
        isFavorite: isFavorite ?? this.isFavorite,
        isPrivate: isPrivate ?? this.isPrivate,
        tags: tags ?? List<String>.from(this.tags),
        groupId: groupId ?? this.groupId,
        seriesName: seriesName ?? this.seriesName,
        seriesIndex: seriesIndex ?? this.seriesIndex,
      );
}

class BookAdapter extends TypeAdapter<Book> {
  @override
  final int typeId = 1;

  @override
  Book read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Book(
      id: fields[0] as String,
      title: fields[1] as String,
      author: (fields[2] as String?) ?? '',
      intro: (fields[3] as String?) ?? '',
      coverPath: fields[4] as String?,
      filePath: fields[5] as String,
      format: BookFormat.values[(fields[6] as int?) ?? 0],
      fileSize: (fields[7] as int?) ?? 0,
      chapterCount: (fields[8] as int?) ?? 0,
      encoding: (fields[9] as String?) ?? 'utf-8',
      chapterRule: fields[10] as String?,
      addedAt: DateTime.fromMillisecondsSinceEpoch((fields[11] as int?) ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch((fields[12] as int?) ?? 0),
      lastReadAt: fields[13] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(fields[13] as int),
      lastChapterIndex: (fields[14] as int?) ?? 0,
      lastOffset: (fields[15] as int?) ?? 0,
      progress: (fields[16] as num?)?.toDouble() ?? 0,
      isFavorite: (fields[17] as bool?) ?? false,
      isPrivate: (fields[18] as bool?) ?? false,
      tags: (fields[19] as List?)?.cast<String>() ?? <String>[],
      groupId: fields[20] as String?,
      seriesName: fields[21] as String?,
      seriesIndex: fields[22] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Book obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.author)
      ..writeByte(3)
      ..write(obj.intro)
      ..writeByte(4)
      ..write(obj.coverPath)
      ..writeByte(5)
      ..write(obj.filePath)
      ..writeByte(6)
      ..write(obj.format.index)
      ..writeByte(7)
      ..write(obj.fileSize)
      ..writeByte(8)
      ..write(obj.chapterCount)
      ..writeByte(9)
      ..write(obj.encoding)
      ..writeByte(10)
      ..write(obj.chapterRule)
      ..writeByte(11)
      ..write(obj.addedAt.millisecondsSinceEpoch)
      ..writeByte(12)
      ..write(obj.updatedAt.millisecondsSinceEpoch)
      ..writeByte(13)
      ..write(obj.lastReadAt?.millisecondsSinceEpoch)
      ..writeByte(14)
      ..write(obj.lastChapterIndex)
      ..writeByte(15)
      ..write(obj.lastOffset)
      ..writeByte(16)
      ..write(obj.progress)
      ..writeByte(17)
      ..write(obj.isFavorite)
      ..writeByte(18)
      ..write(obj.isPrivate)
      ..writeByte(19)
      ..write(obj.tags)
      ..writeByte(20)
      ..write(obj.groupId)
      ..writeByte(21)
      ..write(obj.seriesName)
      ..writeByte(22)
      ..write(obj.seriesIndex);
  }
}
