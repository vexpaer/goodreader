import 'package:hive/hive.dart';

import '../db/hive_setup.dart';
import '../models/book.dart';
import '../models/chapter.dart';

/// Owns every persisted book record and its chapter table.
class BookRepository {
  BookRepository({Box<Book>? box, Box<ChapterList>? chapterBox})
      : _box = box ?? Hive.box<Book>(HiveBoxes.books),
        _chapterBox = chapterBox ?? Hive.box<ChapterList>(HiveBoxes.chapters);

  final Box<Book> _box;
  final Box<ChapterList> _chapterBox;

  Box<Book> get box => _box;

  List<Book> all() => _box.values.toList(growable: false);

  Book? byId(String id) => _box.get(id);

  bool containsPath(String filePath) =>
      _box.values.any((b) => b.filePath == filePath);

  Future<void> save(Book book) => _box.put(book.id, book);

  Future<void> saveAll(Iterable<Book> books) =>
      _box.putAll({for (final b in books) b.id: b});

  ChapterList? chaptersOf(String bookId) => _chapterBox.get(bookId);

  Future<void> saveChapters(ChapterList list) =>
      _chapterBox.put(list.bookId, list);

  Future<void> remove(String bookId) async {
    await _chapterBox.delete(bookId);
    await _box.delete(bookId);
  }

  Future<void> clear() async {
    await _chapterBox.clear();
    await _box.clear();
  }
}
