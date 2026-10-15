import 'dart:typed_data';

import '../../../data/models/chapter.dart';

/// Result of opening a book file.
class OpenedBook {
  OpenedBook({
    required this.chapters,
    this.title,
    this.author,
    this.intro,
    this.coverBytes,
    this.encoding,
  });

  final List<ChapterMeta> chapters;
  final String? title;
  final String? author;
  final String? intro;
  final Uint8List? coverBytes;
  final String? encoding;
}

/// One full-text match inside a book.
class SearchHit {
  SearchHit({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.start,
    required this.end,
    required this.snippet,
  });

  final int chapterIndex;
  final String chapterTitle;

  /// Character offsets relative to the start of the chapter.
  final int start;
  final int end;

  /// Surrounding text for display.
  final String snippet;
}

/// A parsed, readable book. Implementations own their own resources.
abstract class ReaderDocument {
  List<ChapterMeta> get chapters;

  /// Plain text of chapter [index].
  Future<String> chapterText(int index);

  /// Case-insensitive full-text search across the whole book.
  Future<List<SearchHit>> search(String query, {int limit = 200});

  void dispose() {}
}

/// Thrown when a file cannot be parsed.
class BookParseException implements Exception {
  BookParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Builds a short context window around a match, collapsing newlines.
String buildSnippet(String text, int start, int length, {int radius = 24}) {
  final from = (start - radius).clamp(0, text.length);
  final to = (start + length + radius).clamp(0, text.length);
  final prefix = from > 0 ? '…' : '';
  final suffix = to < text.length ? '…' : '';
  final body = text.substring(from, to).replaceAll(RegExp(r'\s+'), ' ').trim();
  return '$prefix$body$suffix';
}
