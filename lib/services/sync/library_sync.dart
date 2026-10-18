import 'dart:convert';

import 'package:goodreader/data/models/book.dart';
import 'package:goodreader/data/models/note.dart';
import 'package:goodreader/data/repositories/book_repository.dart';
import 'package:goodreader/data/repositories/note_repository.dart';
import 'package:goodreader/services/sync/sync_service.dart';

/// 把书架投影成可同步的文档，再把云端文档合回本地。
///
/// 一份文档对应一本书（`book_<id>.json`）或一本书的笔记（`notes_<bookId>.json`）。
/// 文件名是平铺的，不带子目录：WebDAV 的 PROPFIND 与 S3 的 delimiter 列表都只
/// 返回直接子项，子目录会被当成一个集合条目跳过，放进去就再也列不出来。
/// 粒度选在「一本书」而不是「整个书架」是有意的：整个书架一份文档时，两端各改
/// 一本不同的书也会变成整份文档冲突，较新的一侧会把另一侧的书目改动全部抹掉。
/// 按书切分后，冲突最多影响一本。
///
/// 不同步的字段各有理由：
///
/// * `filePath`、`coverPath` 是设备上的绝对路径，换一台机器必然不同
/// * `chapterCount`、`encoding` 是本机解析的产物，同一个文件在不同版本上可能
///   给出不同结果，同步过去只会让两边显示不一致
///
/// 已知限制：删除不传播。删掉一本书或一条笔记后，本地文档要么消失、要么时间戳
/// 变旧，下一次同步会被云端版本拉回来。要修得存墓碑，这一版没做。
class LibrarySync {
  LibrarySync({required this.books, required this.notes});

  final BookRepository books;
  final NoteRepository notes;

  static const bookPrefix = 'book_';
  static const notePrefix = 'notes_';

  /// 汇总本机全部可同步文档。
  ///
  /// 时间戳取数据自己的 `updatedAt`，不能用 `SyncService.document` 那个
  /// 「盖当前时间」的构造：那样每份本地文档都会显得最新，永远只上传不下载。
  List<SyncDocument> collect() {
    final documents = <SyncDocument>[];

    for (final book in books.all()) {
      documents.add(SyncDocument(
        path: '$bookPrefix${book.id}.json',
        payload: jsonEncode({
          ...encodeBook(book),
          'updatedAt': book.updatedAt.millisecondsSinceEpoch,
        }),
      ));
    }

    for (final entry in _notesByBook().entries) {
      final list = entry.value;
      final stamp = list
          .map((n) => n.createdAt.millisecondsSinceEpoch)
          .reduce((a, b) => a > b ? a : b);
      documents.add(SyncDocument(
        path: '$notePrefix${entry.key}.json',
        payload: jsonEncode({
          'bookId': entry.key,
          'updatedAt': stamp,
          'notes': list.map(encodeNote).toList(),
        }),
      ));
    }

    return documents;
  }

  /// 应用一份云端文档。返回 `false` 表示本机没有落地的条件。
  ///
  /// 落不了地的两种情形都跟「文件不在本机」有关：书本身没有文件，或者笔记所属
  /// 的书没有文件。留着这些记录没有意义，但也不能算作下载成功。
  Future<bool> apply(SyncDocument document) async {
    if (document.path.startsWith(bookPrefix)) return _applyBook(document);
    if (document.path.startsWith(notePrefix)) return _applyNotes(document);
    return false;
  }

  Future<bool> _applyBook(SyncDocument document) async {
    final json = _decode(document.payload);
    if (json == null) return false;
    final id = json['id'];
    if (id is! String) return false;

    final local = books.byId(id);
    if (local == null) return false;

    await books.save(mergeBook(local, json));
    return true;
  }

  Future<bool> _applyNotes(SyncDocument document) async {
    final json = _decode(document.payload);
    if (json == null) return false;
    final bookId = json['bookId'];
    if (bookId is! String) return false;
    if (books.byId(bookId) == null) return false;

    final raw = json['notes'];
    final incoming = <BookNote>[];
    if (raw is List) {
      for (final item in raw) {
        final note = decodeNote(item);
        if (note != null) incoming.add(note);
      }
    }

    // 云端这份是较新的一侧，所以本机多出来的笔记视为在别处被删掉了。
    final keep = {for (final note in incoming) note.id};
    for (final note in notes.forBook(bookId)) {
      if (!keep.contains(note.id)) await notes.remove(note.id);
    }
    for (final note in incoming) {
      await notes.save(note);
    }
    return true;
  }

  /// 合并云端记录到本地书籍。
  ///
  /// 阅读进度只在 `fileSize` 一致时采纳。同名同作者的两个版本章节边界可能完全
  /// 不同，字符偏移落到别的段落上比不恢复更糟。书名、标签、收藏这些与文件内容
  /// 无关的字段无条件采纳。
  static Book mergeBook(Book local, Map<String, dynamic> remote) {
    final sameEdition = remote['fileSize'] == local.fileSize;

    return local.copyWith(
      title: _string(remote['title']),
      author: _string(remote['author']),
      intro: _string(remote['intro']),
      tags: _stringList(remote['tags']),
      isFavorite: _bool(remote['isFavorite']),
      isPrivate: _bool(remote['isPrivate']),
      chapterRule: _string(remote['chapterRule']),
      seriesName: _string(remote['seriesName']),
      seriesIndex: _int(remote['seriesIndex']),
      progress: sameEdition ? _double(remote['progress']) : null,
      lastChapterIndex: sameEdition ? _int(remote['lastChapterIndex']) : null,
      lastOffset: sameEdition ? _int(remote['lastOffset']) : null,
      lastReadAt:
          sameEdition ? _dateOrNull(remote['lastReadAt']) : null,
      // 云端时间戳读不出来时保留本地值，不要把书改成 1970 年。
      updatedAt: _dateOrNull(remote['updatedAt']),
    );
  }

  static Map<String, dynamic> encodeBook(Book book) => {
        'id': book.id,
        'title': book.title,
        'author': book.author,
        'intro': book.intro,
        'format': book.format.index,
        'fileSize': book.fileSize,
        'tags': book.tags,
        'isFavorite': book.isFavorite,
        'isPrivate': book.isPrivate,
        'chapterRule': book.chapterRule,
        'seriesName': book.seriesName,
        'seriesIndex': book.seriesIndex,
        'progress': book.progress,
        'lastChapterIndex': book.lastChapterIndex,
        'lastOffset': book.lastOffset,
        'lastReadAt': book.lastReadAt?.millisecondsSinceEpoch,
        'addedAt': book.addedAt.millisecondsSinceEpoch,
      };

  static Map<String, dynamic> encodeNote(BookNote note) => {
        'id': note.id,
        'bookId': note.bookId,
        'type': note.type.index,
        'chapterIndex': note.chapterIndex,
        'start': note.start,
        'end': note.end,
        'text': note.text,
        'note': note.note,
        'color': note.color,
        'createdAt': note.createdAt.millisecondsSinceEpoch,
      };

  /// 坏数据返回 null，由调用方跳过。与其它编解码器一致：不抛异常。
  static BookNote? decodeNote(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final bookId = raw['bookId'];
    if (id is! String || bookId is! String) return null;
    final typeIndex = raw['type'];
    return BookNote(
      id: id,
      bookId: bookId,
      type: typeIndex is int && typeIndex >= 0 && typeIndex < NoteType.values.length
          ? NoteType.values[typeIndex]
          : NoteType.highlight,
      chapterIndex: _int(raw['chapterIndex']) ?? 0,
      start: _int(raw['start']) ?? 0,
      end: _int(raw['end']) ?? 0,
      text: _string(raw['text']) ?? '',
      note: _string(raw['note']) ?? '',
      color: _int(raw['color']) ?? 0xFFFFD54F,
      createdAt: _date(raw['createdAt']),
    );
  }

  Map<String, List<BookNote>> _notesByBook() {
    final out = <String, List<BookNote>>{};
    for (final note in notes.all()) {
      (out[note.bookId] ??= <BookNote>[]).add(note);
    }
    return out;
  }

  static Map<String, dynamic>? _decode(String payload) {
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  static String? _string(Object? value) => value is String ? value : null;

  static int? _int(Object? value) => value is int ? value : null;

  static double? _double(Object? value) => value is num ? value.toDouble() : null;

  static bool? _bool(Object? value) => value is bool ? value : null;

  static List<String>? _stringList(Object? value) {
    if (value is! List) return null;
    return value.whereType<String>().toList(growable: false);
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// 笔记的创建时间是必填的。缺失时给一个极早的时间，让它排在最后，
  /// 而不是让它看起来像刚刚创建。
  static DateTime _date(Object? value) =>
      _dateOrNull(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
}
