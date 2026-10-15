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

/// A parsed, readable book. Implementations own their own resources.
abstract class ReaderDocument {
  List<ChapterMeta> get chapters;

  /// Plain text of chapter [index].
  Future<String> chapterText(int index);

  void dispose() {}
}

/// Thrown when a file cannot be parsed.
class BookParseException implements Exception {
  BookParseException(this.message);

  final String message;

  @override
  String toString() => message;
}
